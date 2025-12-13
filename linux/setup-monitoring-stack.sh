#!/usr/bin/env bash
set -euo pipefail

PROM_RETENTION_TIME="${PROM_RETENTION_TIME:-7d}"
PROM_RETENTION_SIZE="${PROM_RETENTION_SIZE:-20GB}"   # "" disables size cap
SCRAPE_INTERVAL="${SCRAPE_INTERVAL:-5s}"

# Bind addresses (defaults chosen for LAN convenience + safety)
GRAFANA_BIND="${GRAFANA_BIND:-0.0.0.0}"     # LAN-accessible by default
PROM_BIND="${PROM_BIND:-127.0.0.1}"         # keep Prometheus private by default
EXPORTER_BIND="${EXPORTER_BIND:-127.0.0.1}" # keep exporters private by default

BASE_DIR="/opt/monitoring"
PROM_DIR="$BASE_DIR/prometheus"
GRAF_DIR="$BASE_DIR/grafana"
ENV_FILE="$BASE_DIR/.env"
COMPOSE_FILE="$BASE_DIR/compose.yml"

log(){ echo -e "\n==> $*\n"; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

as_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
  fi
}

wait_http() {
  local url="$1" tries="${2:-90}" sleep_s="${3:-1}"
  for _ in $(seq 1 "$tries"); do
    if curl -fsS --max-time 2 "$url" >/dev/null; then return 0; fi
    sleep "$sleep_s"
  done
  echo "ERROR: timed out waiting for $url"
  return 1
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

main() {
  as_root "$@"

  apt-get update -y
  apt-get install -y ca-certificates curl openssl

  has_cmd docker || { echo "ERROR: docker not found"; exit 1; }
  ensure_docker_running_socket_activation

  mkdir -p "$PROM_DIR" \
           "$GRAF_DIR/provisioning/datasources" \
           "$GRAF_DIR/provisioning/dashboards" \
           "$GRAF_DIR/dashboards"

  cat >"$PROM_DIR/prometheus.yml" <<YML
global:
  scrape_interval: ${SCRAPE_INTERVAL}
  evaluation_interval: ${SCRAPE_INTERVAL}

scrape_configs:
  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "dcgm"
    static_configs:
      - targets: ["dcgm-exporter:9400"]
YML

  # Datasource provisioning: force uid PROM + prune/delete for idempotency
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

  # Host Overview dashboard (CPU temp + CPU watts + GPU watts + CPU usage)
  cat >"$GRAF_DIR/dashboards/host-overview.json" <<'JSON'
{
  "uid": "host-overview",
  "title": "Host Overview",
  "timezone": "browser",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "5s",
  "panels": [
    {
      "id": 1,
      "type": "timeseries",
      "title": "CPU Temp (k10temp Tctl)",
      "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 },
      "targets": [
        {
          "refId": "A",
          "expr": "node_hwmon_temp_celsius{sensor=\"temp1\"} * on (chip) group_left(chip_name) node_hwmon_chip_names{chip_name=\"k10temp\"}"
        }
      ],
      "fieldConfig": { "defaults": { "unit": "celsius" }, "overrides": [] }
    },
    {
      "id": 2,
      "type": "timeseries",
      "title": "CPU Package Power (W) (RAPL)",
      "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 12, "y": 0, "w": 12, "h": 8 },
      "targets": [
        {
          "refId": "A",
          "expr": "sum(rate(node_rapl_package_joules_total[1m]))"
        }
      ],
      "fieldConfig": { "defaults": { "unit": "watt" }, "overrides": [] }
    },
    {
      "id": 3,
      "type": "timeseries",
      "title": "Total GPU Power (W)",
      "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 0, "y": 8, "w": 12, "h": 8 },
      "targets": [
        { "refId": "A", "expr": "sum(DCGM_FI_DEV_POWER_USAGE)" }
      ],
      "fieldConfig": { "defaults": { "unit": "watt" }, "overrides": [] }
    },
    {
      "id": 4,
      "type": "timeseries",
      "title": "CPU Usage (%)",
      "datasource": { "type": "prometheus", "uid": "PROM" },
      "gridPos": { "x": 12, "y": 8, "w": 12, "h": 8 },
      "targets": [
        { "refId": "A", "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[2m])) * 100)" }
      ],
      "fieldConfig": { "defaults": { "unit": "percent" }, "overrides": [] }
    }
  ]
}
JSON

  if [[ ! -f "$ENV_FILE" ]]; then
    PASS="$(openssl rand -base64 18 | tr -d '\n' | tr '/+' 'ab')"
    cat >"$ENV_FILE" <<EOF
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=$PASS
EOF
    chmod 600 "$ENV_FILE"
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
    ports:
      - "${EXPORTER_BIND}:9400:9400"

  node-exporter:
    image: quay.io/prometheus/node-exporter:latest
    restart: unless-stopped
    user: "0:0"   # REQUIRED: /sys/class/powercap/*/energy_uj is root-only on this host
    pid: "host"
    command:
      - "--collector.hwmon"
      - "--collector.rapl"
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
      - prometheus-data:/prometheus
    ports:
      - "${PROM_BIND}:9090:9090"

  grafana:
    image: grafana/grafana-oss:latest
    restart: unless-stopped
    env_file: [ "./.env" ]
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    ports:
      - "${GRAFANA_BIND}:3000:3000"

volumes:
  prometheus-data:
  grafana-data:
EOF

  log "Starting/refreshing stack"
  cd "$BASE_DIR"
  docker compose -f "$COMPOSE_FILE" up -d

  # Grafana applies datasource provisioning on startup; restart to apply ds.yml UID changes reliably
  docker compose -f "$COMPOSE_FILE" restart grafana

  log "Waiting for services (prevents racey curl failures)"
  wait_http "http://127.0.0.1:9400/metrics" 90 1
  wait_http "http://127.0.0.1:9100/metrics" 90 1
  wait_http "http://127.0.0.1:9090/-/ready" 90 1
  wait_http "http://127.0.0.1:3000/api/health" 120 1 || true

  log "Checking that CPU power metrics (RAPL) are present"
  tmp="$(mktemp)"
  if curl -fsS --max-time 3 http://127.0.0.1:9100/metrics -o "$tmp"; then
    if grep -q '^node_rapl_' "$tmp"; then
      echo "OK: node_rapl_* metrics found — CPU watts available in Grafana."
    else
      echo "WARNING: node_rapl_* metrics not found yet."
      echo "         Next: cd $BASE_DIR && sudo docker compose logs --tail=250 node-exporter"
    fi
  else
    echo "WARNING: couldn't fetch node-exporter metrics for RAPL check."
  fi
  rm -f "$tmp"

  local ip
  ip="$(hostname -I | awk '{print $1}')"
  echo
  echo "Grafana LAN URL: http://${ip}:3000"
  echo "Grafana password: sudo cat ${ENV_FILE}"
  echo "Dashboards: Host Overview, NVIDIA DCGM Exporter Dashboard"
}
main "$@"
