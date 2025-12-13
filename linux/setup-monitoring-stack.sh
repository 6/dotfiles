#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Tunables (override via env)
# -----------------------------
PROM_RETENTION_TIME="${PROM_RETENTION_TIME:-7d}"
PROM_RETENTION_SIZE="${PROM_RETENTION_SIZE:-20GB}"   # "" disables size cap
SCRAPE_INTERVAL="${SCRAPE_INTERVAL:-5s}"

# Bind addresses
GRAFANA_BIND_LOCAL="${GRAFANA_BIND_LOCAL:-127.0.0.1}"  # Grafana stays local-only
PROM_BIND="${PROM_BIND:-127.0.0.1}"
EXPORTER_BIND="${EXPORTER_BIND:-127.0.0.1}"
ALERT_BIND="${ALERT_BIND:-127.0.0.1}"

# Hostname users browse to (should resolve on your LAN)
GRAFANA_HOSTNAME="${GRAFANA_HOSTNAME:-$(hostname).local}"
GRAFANA_PUBLIC_URL="${GRAFANA_PUBLIC_URL:-https://${GRAFANA_HOSTNAME}}"

# Alert thresholds (Prometheus -> Alertmanager -> Slack)
ALERT_CPU_TEMP_C="${ALERT_CPU_TEMP_C:-90}"
ALERT_CPU_POWER_W="${ALERT_CPU_POWER_W:-200}"
ALERT_GPU_TEMP_C="${ALERT_GPU_TEMP_C:-85}"
ALERT_GPU_POWER_W="${ALERT_GPU_POWER_W:-290}"
ALERT_VRAM_PCT="${ALERT_VRAM_PCT:-95}"

# Optional knobs
ENABLE_HOURLY_SNAPSHOT="${ENABLE_HOURLY_SNAPSHOT:-0}"
ENABLE_TEST_ALERT="${ENABLE_TEST_ALERT:-0}"

# REQUIRED: Slack webhook used by Alertmanager (+ optional snapshot)
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

# Wait behavior
WAIT_SECS_DEFAULT="${WAIT_SECS_DEFAULT:-60}"     # user requested ~60s
WAIT_LOG_EVERY="${WAIT_LOG_EVERY:-10}"           # print logs every N seconds
WAIT_LOG_LINES="${WAIT_LOG_LINES:-2}"            # print last N log lines each time

BASE_DIR="/opt/monitoring"
PROM_DIR="$BASE_DIR/prometheus"
GRAF_DIR="$BASE_DIR/grafana"
AM_DIR="$BASE_DIR/alertmanager"
DCGM_DIR="$BASE_DIR/dcgm"
CADDY_DIR="$BASE_DIR/caddy"
ENV_FILE="$BASE_DIR/.env"
COMPOSE_FILE="$BASE_DIR/compose.yml"

SYSTEMD_ENV_DIR="/etc/monitoring"
SYSTEMD_ENV_FILE="$SYSTEMD_ENV_DIR/slack.env"
SNAPSHOT_BIN="/usr/local/bin/monitoring-hourly-snapshot.sh"
SNAPSHOT_SVC="/etc/systemd/system/monitoring-hourly-snapshot.service"
SNAPSHOT_TMR="/etc/systemd/system/monitoring-hourly-snapshot.timer"

log(){ echo -e "\n==> $*\n"; }

as_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    exec sudo \
      --preserve-env=SLACK_WEBHOOK_URL,ENABLE_HOURLY_SNAPSHOT,ENABLE_TEST_ALERT,PROM_RETENTION_TIME,PROM_RETENTION_SIZE,SCRAPE_INTERVAL,GRAFANA_HOSTNAME,GRAFANA_PUBLIC_URL,GRAFANA_BIND_LOCAL,PROM_BIND,EXPORTER_BIND,ALERT_BIND,ALERT_CPU_TEMP_C,ALERT_CPU_POWER_W,ALERT_GPU_TEMP_C,ALERT_GPU_POWER_W,ALERT_VRAM_PCT,WAIT_SECS_DEFAULT,WAIT_LOG_EVERY,WAIT_LOG_LINES \
      -E bash "$0" "$@"
  fi
}

require_slack_webhook() {
  if [[ -n "${SLACK_WEBHOOK_URL}" ]]; then return 0; fi
  cat <<EOF
ERROR: SLACK_WEBHOOK_URL is required.

Run like:
  SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...' $0

If you run sudo yourself:
  SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...' sudo --preserve-env=SLACK_WEBHOOK_URL $0
EOF
  exit 1
}

fix_env_permissions_for_user() {
  local u="${SUDO_USER:-}"
  [[ -z "$u" ]] && return 0
  local g; g="$(id -gn "$u" 2>/dev/null || true)"
  [[ -z "$g" ]] && return 0
  chgrp "$g" "$ENV_FILE" || true
  chmod 640 "$ENV_FILE" || true
}

ensure_docker_running_socket_activation() {
  log "Ensuring docker.socket + docker.service are running (socket activation)"
  systemctl daemon-reload || true
  systemctl reset-failed docker.service docker.socket || true
  systemctl enable docker.socket docker.service >/dev/null 2>&1 || true
  systemctl start docker.socket
  systemctl start docker.service

  systemctl is-active --quiet docker.socket || { systemctl status docker.socket --no-pager -l || true; exit 1; }
  systemctl is-active --quiet docker.service || {
    systemctl status docker.service --no-pager -l || true
    journalctl -u docker -b --no-pager -l | tail -n 200 || true
    exit 1
  }

  docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose not found"; exit 1; }
}

wait_http_with_logs() {
  local name="$1" url="$2" tries="${3:-60}" sleep_s="${4:-1}" service="${5:-}" curl_args="${6:-}"
  echo "Waiting: $name ($url) ..."
  for i in $(seq 1 "$tries"); do
    # shellcheck disable=SC2086
    if curl -fsS --max-time 2 $curl_args "$url" >/dev/null 2>&1; then
      echo "OK: $name"
      return 0
    fi
    if (( i % WAIT_LOG_EVERY == 0 )); then
      echo "  ...still waiting ($i/${tries}) for $name"
      if [[ -n "$service" ]]; then
        echo "  --- last ${WAIT_LOG_LINES} log lines: $service ---"
        docker compose -f "$COMPOSE_FILE" logs --tail="${WAIT_LOG_LINES}" "$service" 2>/dev/null | sed 's/^/  /' || true
        echo "  ----------------------------------------"
      fi
    fi
    sleep "$sleep_s"
  done
  echo "ERROR: timed out waiting for $name ($url)"
  if [[ -n "$service" ]]; then
    echo "Last ~200 lines of $service logs:"
    docker compose -f "$COMPOSE_FILE" logs --tail=200 "$service" || true
  fi
  return 1
}

download_default_collectors() {
  mkdir -p "$DCGM_DIR"
  # Use the DCGM exporter default counters file; no throttle-reasons metric (it breaks on some stacks)
  curl -fsSL -o "$DCGM_DIR/collectors.csv" \
    "https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/main/etc/default-counters.csv"
}

write_caddyfile() {
  mkdir -p "$CADDY_DIR"
  cat >"$CADDY_DIR/Caddyfile" <<EOF
${GRAFANA_HOSTNAME} {
  reverse_proxy grafana:3000
  tls internal
}
EOF
}

write_alertmanager_config() {
  mkdir -p "$AM_DIR"
  local graf_url
  graf_url="${GRAFANA_PUBLIC_URL}/d/host-overview/host-overview?orgId=1"

  cat >"$AM_DIR/alertmanager.yml" <<EOF
global:
  resolve_timeout: 5m

route:
  receiver: "slack"
  group_by: ["alertname", "instance", "gpu"]
  group_wait: 10s
  group_interval: 10m
  repeat_interval: 1h

receivers:
  - name: "slack"
    slack_configs:
      - api_url: "${SLACK_WEBHOOK_URL}"
        username: "prometheus"
        send_resolved: false
        title: "{{ range .Alerts }}[{{ .Labels.severity }}] {{ .Annotations.summary }}{{ end }}"
        title_link: "${graf_url}"
        text: "{{ range .Alerts }}• {{ .Annotations.description }} (value={{ printf \\"%.2f\\" .Value }})\\n{{ end }}\\nGrafana: ${graf_url}"
EOF
}

install_hourly_snapshot_timer() {
  mkdir -p "$SYSTEMD_ENV_DIR"
  cat >"$SYSTEMD_ENV_FILE" <<EOF
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL}
EOF
  chmod 600 "$SYSTEMD_ENV_FILE"

  local graf_url
  graf_url="${GRAFANA_PUBLIC_URL}/d/host-overview/host-overview?orgId=1"

  cat >"$SNAPSHOT_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
PROM_URL="${PROM_URL:-http://127.0.0.1:9090}"
GRAFANA_URL="${GRAFANA_URL:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing $1"; exit 1; }; }
need curl; need jq; need python3

q1() {
  local query="$1"
  curl -fsS -G --max-time 6 --data-urlencode "query=${query}" "${PROM_URL}/api/v1/query" \
    | jq -r '.data.result[0].value[1] // empty'
}

qlist() {
  local query="$1"
  curl -fsS -G --max-time 6 --data-urlencode "query=${query}" "${PROM_URL}/api/v1/query" \
    | jq -r '.data.result[]? | "\(.metric | to_entries | map("\(.key)=\(.value)") | join(",")) \(.value[1])"'
}

fmtf() { local v="${1:-}"; [[ -z "$v" ]] && echo "n/a" || printf "%.1f" "$v"; }

human_bps() {
  python3 - <<PY
v=float("${1:-0}" or 0)
units=["B/s","KB/s","MB/s","GB/s","TB/s"]
i=0
while v>=1024 and i<len(units)-1:
  v/=1024
  i+=1
print(f"{v:.2f} {units[i]}")
PY
}

# CPU
cpu_temp="$(q1 'node_hwmon_temp_celsius{sensor="temp1"} * on (chip) group_left(chip_name) node_hwmon_chip_names{chip_name="k10temp"}')"
cpu_w="$(q1 'sum(rate(node_rapl_package_joules_total[1m]))')"
cpu_usage="$(q1 '100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)')"

# GPU
gpu_temps="$(qlist 'avg by (gpu) (DCGM_FI_DEV_GPU_TEMP)')"
gpu_pwrs="$(qlist 'sum by (gpu) (DCGM_FI_DEV_POWER_USAGE)')"
gpu_vram="$(qlist '100 * sum by (gpu) (DCGM_FI_DEV_FB_USED) / clamp_min( sum by (gpu) (DCGM_FI_DEV_FB_USED) + sum by (gpu) (DCGM_FI_DEV_FB_FREE) + sum by (gpu) (DCGM_FI_DEV_FB_RESERVED), 1)')"
gpu_clk="$(qlist 'avg by (gpu) (DCGM_FI_DEV_SM_CLOCK)')"

# NVMe temps + disk IO
nvme_temps="$(qlist 'node_hwmon_temp_celsius{chip=~"nvme_nvme[0-9]+",sensor="temp1"}')"
disk_read_bps="$(q1 'sum(rate(node_disk_read_bytes_total{device=~"nvme[0-9]+n[0-9]+"}[1m]))')"
disk_write_bps="$(q1 'sum(rate(node_disk_written_bytes_total{device=~"nvme[0-9]+n[0-9]+"}[1m]))')"

r_h="$(human_bps "${disk_read_bps:-0}")"
w_h="$(human_bps "${disk_write_bps:-0}")"

host="$(hostname)"
ts="$(date -Is)"

msg="*Hourly snapshot* (${host})\n${ts}\n"
msg+="\n*CPU*: temp=$(fmtf "$cpu_temp")°C  power=$(fmtf "$cpu_w")W  usage=$(fmtf "$cpu_usage")%\n"
msg+="\n*GPU temps (°C)*:\n$(echo "${gpu_temps}" | sed 's/^/  - /')\n"
msg+="\n*GPU power (W)*:\n$(echo "${gpu_pwrs}" | sed 's/^/  - /')\n"
msg+="\n*GPU VRAM (%)*:\n$(echo "${gpu_vram}" | sed 's/^/  - /')\n"
msg+="\n*GPU SM clocks (MHz)*:\n$(echo "${gpu_clk}" | sed 's/^/  - /')\n"
msg+="\n*NVMe temps (°C)*:\n$(echo "${nvme_temps}" | sed 's/^/  - /')\n"
msg+="\n*NVMe disk IO*: read=${r_h}, write=${w_h}\n"
[[ -n "$GRAFANA_URL" ]] && msg+="\nGrafana: ${GRAFANA_URL}\n"

payload="$(jq -n --arg text "$msg" '{text:$text}')"
curl -fsS --max-time 8 -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL" >/dev/null
EOF
  chmod 755 "$SNAPSHOT_BIN"

  cat >"$SNAPSHOT_SVC" <<EOF
[Unit]
Description=Post hourly monitoring snapshot to Slack
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=${SYSTEMD_ENV_FILE}
Environment=PROM_URL=http://127.0.0.1:9090
Environment=GRAFANA_URL=${graf_url}
ExecStart=${SNAPSHOT_BIN}
EOF

  cat >"$SNAPSHOT_TMR" <<EOF
[Unit]
Description=Run hourly monitoring snapshot

[Timer]
OnCalendar=hourly
Persistent=true
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now monitoring-hourly-snapshot.timer
}

main() {
  as_root "$@"
  require_slack_webhook

  apt-get update -y
  apt-get install -y ca-certificates curl openssl jq python3

  ensure_docker_running_socket_activation

  mkdir -p "$PROM_DIR" \
           "$GRAF_DIR/provisioning/datasources" \
           "$GRAF_DIR/provisioning/dashboards" \
           "$GRAF_DIR/dashboards" \
           "$AM_DIR" \
           "$DCGM_DIR" \
           "$CADDY_DIR"

  download_default_collectors
  write_caddyfile
  write_alertmanager_config

  # -----------------------------
  # Prometheus alert rules
  # -----------------------------
  cat >"$PROM_DIR/alerts.yml" <<YML
groups:
  - name: host-and-gpu
    rules:
      - alert: HostCPUHighTemp
        expr: |
          (node_hwmon_temp_celsius{sensor="temp1"} * on (chip) group_left(chip_name) node_hwmon_chip_names{chip_name="k10temp"}) > ${ALERT_CPU_TEMP_C}
        for: 5m
        labels: { severity: warning }
        annotations:
          summary: "CPU temperature high"
          description: "CPU temp > ${ALERT_CPU_TEMP_C}°C for 5m on {{ \$labels.instance }}"

      - alert: HostCPUPackageHighPower
        expr: sum(rate(node_rapl_package_joules_total[1m])) > ${ALERT_CPU_POWER_W}
        for: 5m
        labels: { severity: warning }
        annotations:
          summary: "CPU package power high"
          description: "CPU package power > ${ALERT_CPU_POWER_W}W for 5m on {{ \$labels.instance }}"

      - alert: GPUHighTemp
        expr: avg by (gpu) (DCGM_FI_DEV_GPU_TEMP) > ${ALERT_GPU_TEMP_C}
        for: 5m
        labels: { severity: warning }
        annotations:
          summary: "GPU temperature high"
          description: "GPU {{ \$labels.gpu }} temp > ${ALERT_GPU_TEMP_C}°C for 5m"

      - alert: GPUHighPower
        expr: sum by (gpu) (DCGM_FI_DEV_POWER_USAGE) > ${ALERT_GPU_POWER_W}
        for: 5m
        labels: { severity: warning }
        annotations:
          summary: "GPU power high"
          description: "GPU {{ \$labels.gpu }} power > ${ALERT_GPU_POWER_W}W for 5m"

      - alert: GPUHighVRAMUsage
        expr: |
          (
            100 * sum by (gpu) (DCGM_FI_DEV_FB_USED)
            /
            clamp_min(
              sum by (gpu) (DCGM_FI_DEV_FB_USED)
              + sum by (gpu) (DCGM_FI_DEV_FB_FREE)
              + sum by (gpu) (DCGM_FI_DEV_FB_RESERVED),
              1
            )
          ) > ${ALERT_VRAM_PCT}
        for: 5m
        labels: { severity: warning }
        annotations:
          summary: "GPU VRAM usage high"
          description: "GPU {{ \$labels.gpu }} VRAM > ${ALERT_VRAM_PCT}% for 5m"
YML

  if [[ "${ENABLE_TEST_ALERT}" == "1" ]]; then
    cat >>"$PROM_DIR/alerts.yml" <<'YML'

  - name: test
    rules:
      - alert: TestSlackPipeline
        expr: vector(1)
        for: 0m
        labels: { severity: info }
        annotations:
          summary: "TestSlackPipeline"
          description: "This is a test alert to validate Prometheus → Alertmanager → Slack."
YML
  fi

  cat >"$PROM_DIR/prometheus.yml" <<YML
global:
  scrape_interval: ${SCRAPE_INTERVAL}
  evaluation_interval: ${SCRAPE_INTERVAL}

rule_files:
  - /etc/prometheus/alerts.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

scrape_configs:
  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "dcgm"
    static_configs:
      - targets: ["dcgm-exporter:9400"]
YML

  # -----------------------------
  # Grafana provisioning (datasource UID fixed to PROM)
  # -----------------------------
  cat >"$GRAF_DIR/provisioning/datasources/ds.yml" <<'YML'
apiVersion: 1
prune: true
deleteDatasources:
  - name: Prometheus
    orgId: 1
datasources:
  - name: Prometheus
    uid: PROM
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    version: 1
YML

  cat >"$GRAF_DIR/provisioning/dashboards/dash.yml" <<'YML'
apiVersion: 1
providers:
  - name: "Provisioned"
    orgId: 1
    folder: ""
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
YML

  # NVIDIA dashboard
  if [[ ! -f "$GRAF_DIR/dashboards/dcgm-exporter-dashboard.json" ]]; then
    curl -fsSL -o "$GRAF_DIR/dashboards/dcgm-exporter-dashboard.json" \
      "https://github.com/NVIDIA/dcgm-exporter/raw/main/grafana/dcgm-exporter-dashboard.json"
  fi

  # Host Overview (15m default + shaded red above thresholds)
  cat >"$GRAF_DIR/dashboards/host-overview.json" <<JSON
{
  "uid": "host-overview",
  "title": "Host Overview",
  "timezone": "browser",
  "schemaVersion": 39,
  "version": 3,
  "refresh": "5s",
  "time": { "from": "now-15m", "to": "now" },
  "panels": [
    { "id": 1, "type": "timeseries", "title": "CPU Temp (k10temp Tctl)", "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 0, "y": 0, "w": 8, "h": 7 },
      "targets": [ { "refId": "A", "expr": "node_hwmon_temp_celsius{sensor=\\"temp1\\"} * on (chip) group_left(chip_name) node_hwmon_chip_names{chip_name=\\"k10temp\\"}", "legendFormat": "CPU Tctl" } ],
      "fieldConfig": { "defaults": { "unit": "celsius", "min": 0,
        "thresholds": { "mode": "absolute", "steps": [ { "color": "green", "value": null }, { "color": "red", "value": ${ALERT_CPU_TEMP_C} } ] },
        "custom": { "thresholdsStyle": { "mode": "area" } } }, "overrides": [] } },

    { "id": 2, "type": "timeseries", "title": "CPU Package Power (W) (RAPL)", "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 8, "y": 0, "w": 8, "h": 7 },
      "targets": [ { "refId": "A", "expr": "sum(rate(node_rapl_package_joules_total[1m]))", "legendFormat": "CPU Package W" } ],
      "fieldConfig": { "defaults": { "unit": "watt", "min": 0 }, "overrides": [] } },

    { "id": 3, "type": "timeseries", "title": "CPU Usage (%)", "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 16, "y": 0, "w": 8, "h": 7 },
      "targets": [ { "refId": "A", "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\\"idle\\"}[2m])) * 100)", "legendFormat": "CPU %" } ],
      "fieldConfig": { "defaults": { "unit": "percent", "min": 0, "max": 100 }, "overrides": [] } },

    { "id": 4, "type": "timeseries", "title": "GPU Temps (°C) (per GPU)", "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 0, "y": 7, "w": 8, "h": 7 },
      "targets": [ { "refId": "A", "expr": "avg by (gpu) (DCGM_FI_DEV_GPU_TEMP)", "legendFormat": "GPU {{gpu}}" } ],
      "fieldConfig": { "defaults": { "unit": "celsius", "min": 0,
        "thresholds": { "mode": "absolute", "steps": [ { "color": "green", "value": null }, { "color": "red", "value": ${ALERT_GPU_TEMP_C} } ] },
        "custom": { "thresholdsStyle": { "mode": "area" } } }, "overrides": [] } },

    { "id": 5, "type": "timeseries", "title": "GPU Power (W) Stacked (per GPU) + Total", "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 8, "y": 7, "w": 8, "h": 7 },
      "targets": [
        { "refId": "A", "expr": "sum by (gpu) (DCGM_FI_DEV_POWER_USAGE)", "legendFormat": "GPU {{gpu}}" },
        { "refId": "B", "expr": "sum(DCGM_FI_DEV_POWER_USAGE)", "legendFormat": "Total" }
      ],
      "fieldConfig": { "defaults": { "unit": "watt", "min": 0, "custom": { "fillOpacity": 25, "stacking": { "mode": "normal", "group": "gpuPower" } } },
        "overrides": [ { "matcher": { "id": "byName", "options": "Total" }, "properties": [
          { "id": "custom.stacking", "value": { "mode": "none", "group": "gpuPower" } },
          { "id": "custom.fillOpacity", "value": 0 },
          { "id": "custom.lineWidth", "value": 2 }
        ] } ] } },

    { "id": 6, "type": "timeseries", "title": "VRAM Usage (%) (per GPU)", "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 16, "y": 7, "w": 8, "h": 7 },
      "targets": [ { "refId": "A", "expr": "100 * sum by (gpu) (DCGM_FI_DEV_FB_USED) / clamp_min(sum by (gpu) (DCGM_FI_DEV_FB_USED) + sum by (gpu) (DCGM_FI_DEV_FB_FREE) + sum by (gpu) (DCGM_FI_DEV_FB_RESERVED), 1)", "legendFormat": "GPU {{gpu}}" } ],
      "fieldConfig": { "defaults": { "unit": "percent", "min": 0, "max": 100 }, "overrides": [] } },

    { "id": 7, "type": "timeseries", "title": "NVMe Temps (Composite) (°C)", "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 0, "y": 14, "w": 8, "h": 7 },
      "targets": [ { "refId": "A", "expr": "node_hwmon_temp_celsius{chip=~\\"nvme_nvme[0-9]+\\",sensor=\\"temp1\\"}", "legendFormat": "{{chip}}" } ],
      "fieldConfig": { "defaults": { "unit": "celsius", "min": 0 }, "overrides": [] } },

    { "id": 8, "type": "timeseries", "title": "NVMe Read/Write Bytes (B/s) (sum)", "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 8, "y": 14, "w": 8, "h": 7 },
      "targets": [
        { "refId": "A", "expr": "sum(rate(node_disk_read_bytes_total{device=~\\"nvme[0-9]+n[0-9]+\\"}[1m]))", "legendFormat": "Read" },
        { "refId": "B", "expr": "-sum(rate(node_disk_written_bytes_total{device=~\\"nvme[0-9]+n[0-9]+\\"}[1m]))", "legendFormat": "Write (-)" }
      ],
      "fieldConfig": { "defaults": { "unit": "Bps" }, "overrides": [] } },

    { "id": 9, "type": "timeseries", "title": "GPU SM Clock (MHz) (per GPU)", "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 16, "y": 14, "w": 8, "h": 7 },
      "targets": [ { "refId": "A", "expr": "avg by (gpu) (DCGM_FI_DEV_SM_CLOCK)", "legendFormat": "GPU {{gpu}}" } ],
      "fieldConfig": { "defaults": { "unit": "mhz", "min": 0 }, "overrides": [] } }
  ]
}
JSON

  # Grafana env (root_url so links are https)
  if [[ ! -f "$ENV_FILE" ]]; then
    PASS="$(openssl rand -base64 18 | tr -d '\n' | tr '/+' 'ab')"
    cat >"$ENV_FILE" <<EOF
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=$PASS
GF_SERVER_DOMAIN=${GRAFANA_HOSTNAME}
GF_SERVER_ROOT_URL=${GRAFANA_PUBLIC_URL}
EOF
    chmod 600 "$ENV_FILE"
  else
    grep -q '^GF_SERVER_DOMAIN=' "$ENV_FILE" || echo "GF_SERVER_DOMAIN=${GRAFANA_HOSTNAME}" >>"$ENV_FILE"
    grep -q '^GF_SERVER_ROOT_URL=' "$ENV_FILE" || echo "GF_SERVER_ROOT_URL=${GRAFANA_PUBLIC_URL}" >>"$ENV_FILE"
  fi
  fix_env_permissions_for_user

  local size_line=""
  if [[ -n "$PROM_RETENTION_SIZE" ]]; then
    size_line="      - '--storage.tsdb.retention.size=${PROM_RETENTION_SIZE}'"
  fi

  cat >"$COMPOSE_FILE" <<EOF
services:
  dcgm-exporter:
    image: nvcr.io/nvidia/k8s/dcgm-exporter:4.4.2-4.7.1-ubuntu22.04
    restart: unless-stopped
    gpus: all
    cap_add: [ "SYS_ADMIN" ]
    command: ["-f", "/etc/dcgm-exporter/collectors.csv"]
    volumes:
      - ./dcgm/collectors.csv:/etc/dcgm-exporter/collectors.csv:ro
    ports:
      - "${EXPORTER_BIND}:9400:9400"

  node-exporter:
    image: quay.io/prometheus/node-exporter:latest
    restart: unless-stopped
    user: "0:0"
    pid: "host"
    command:
      - "--collector.hwmon"
      - "--collector.rapl"
      - "--collector.cpufreq"
      - "--path.procfs=/host/proc"
      - "--path.sysfs=/host/sys"
      - "--path.rootfs=/rootfs"
      - "--path.udev.data=/rootfs/run/udev/data"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro,rslave
    ports:
      - "${EXPORTER_BIND}:9100:9100"

  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=${PROM_RETENTION_TIME}'
${size_line}
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/alerts.yml:/etc/prometheus/alerts.yml:ro
      - prometheus-data:/prometheus
    ports:
      - "${PROM_BIND}:9090:9090"

  alertmanager:
    image: prom/alertmanager:latest
    restart: unless-stopped
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager-data:/alertmanager
    ports:
      - "${ALERT_BIND}:9093:9093"

  grafana:
    image: grafana/grafana-oss:latest
    restart: unless-stopped
    env_file: [ "./.env" ]
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    ports:
      - "${GRAFANA_BIND_LOCAL}:3000:3000"

  caddy:
    image: caddy:2
    restart: unless-stopped
    depends_on:
      - grafana
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config

volumes:
  prometheus-data:
  grafana-data:
  alertmanager-data:
  caddy-data:
  caddy-config:
EOF

  log "Starting/refreshing stack"
  cd "$BASE_DIR"
  docker compose -f "$COMPOSE_FILE" up -d

  log "Recreating prometheus + alertmanager + grafana to apply configs deterministically"
  docker compose -f "$COMPOSE_FILE" up -d --force-recreate prometheus alertmanager grafana

  log "Waiting for services"
  docker compose -f "$COMPOSE_FILE" ps || true

  wait_http_with_logs "dcgm-exporter metrics" "http://127.0.0.1:9400/metrics" "$WAIT_SECS_DEFAULT" 1 "dcgm-exporter"
  wait_http_with_logs "node-exporter metrics" "http://127.0.0.1:9100/metrics" "$WAIT_SECS_DEFAULT" 1 "node-exporter"
  wait_http_with_logs "prometheus ready"      "http://127.0.0.1:9090/-/ready"  "$WAIT_SECS_DEFAULT" 1 "prometheus"
  wait_http_with_logs "alertmanager ready"    "http://127.0.0.1:9093/-/ready"  "$WAIT_SECS_DEFAULT" 1 "alertmanager"
  wait_http_with_logs "grafana health"        "http://127.0.0.1:3000/api/health" "$WAIT_SECS_DEFAULT" 1 "grafana"

  # Caddy checks that don't depend on DNS or CA trust:
  # 1) Ensure port 80 answers with the right Host header (usually redirect to https)
  wait_http_with_logs "caddy http (Host header)" "http://127.0.0.1/" "$WAIT_SECS_DEFAULT" 1 "caddy" "-H Host:${GRAFANA_HOSTNAME} -I"

  # 2) Optional: ensure TLS listener answers (ignore trust just for readiness)
  wait_http_with_logs "caddy https (insecure readiness)" "https://${GRAFANA_HOSTNAME}/" "$WAIT_SECS_DEFAULT" 1 "caddy" "-k --resolve ${GRAFANA_HOSTNAME}:443:127.0.0.1 -I"

  if [[ "${ENABLE_HOURLY_SNAPSHOT}" == "1" ]]; then
    log "Installing hourly snapshot systemd timer (posts inline stats to Slack)"
    install_hourly_snapshot_timer
    systemctl status monitoring-hourly-snapshot.timer --no-pager -l || true
  fi

  log "Sanity checks"
  tmp="$(mktemp)"
  curl -fsS --max-time 4 http://127.0.0.1:9400/metrics -o "$tmp" || true
  if grep -q '^DCGM_FI_DEV_FB_USED' "$tmp" && grep -q '^DCGM_FI_DEV_FB_FREE' "$tmp" && grep -q '^DCGM_FI_DEV_FB_RESERVED' "$tmp"; then
    echo "OK: DCGM VRAM metrics present (USED/FREE/RESERVED)."
  else
    echo "WARN: DCGM VRAM metrics missing; check dcgm-exporter logs."
  fi
  rm -f "$tmp"

  tmp="$(mktemp)"
  curl -fsS --max-time 4 http://127.0.0.1:9100/metrics -o "$tmp" || true
  if grep -q '^node_rapl_' "$tmp"; then
    echo "OK: node_rapl_* metrics present (CPU package power)."
  else
    echo "WARN: node_rapl_* metrics missing; check node-exporter logs."
  fi
  rm -f "$tmp"

  echo
  echo "HTTPS Grafana: ${GRAFANA_PUBLIC_URL}"
  echo "Local Grafana (localhost only): http://127.0.0.1:3000"
  echo "Grafana password: sudo cat ${ENV_FILE}"
  echo

  cat <<EOF

--- macOS: trust the Caddy root CA (stop repeating HTTPS warnings) ---
1) Export the Caddy root CA from the server (writes /opt/monitoring/caddy-root.crt):
   cd /opt/monitoring && sudo docker compose -f ${COMPOSE_FILE} cp caddy:/data/caddy/pki/authorities/local/root.crt ./caddy-root.crt

2) Copy it to your Mac (example):
   scp peter@${GRAFANA_HOSTNAME}:/opt/monitoring/caddy-root.crt ~/Downloads/

3) On the Mac, install it into the *System* keychain as a trusted root:
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/Downloads/caddy-root.crt

   If you get error -25294 (duplicate), delete existing Caddy cert(s) and retry:
     sudo security find-certificate -a -c "Caddy Local Authority" -Z /Library/Keychains/System.keychain
     # pick a SHA-1 from output, then:
     sudo security delete-certificate -Z <SHA1> /Library/Keychains/System.keychain
     sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/Downloads/caddy-root.crt
---------------------------------------------------------------------
EOF
}

main "$@"
