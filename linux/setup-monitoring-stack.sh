#!/usr/bin/env bash
set -euo pipefail

PROM_RETENTION_TIME="${PROM_RETENTION_TIME:-7d}"
PROM_RETENTION_SIZE="${PROM_RETENTION_SIZE:-20GB}"   # "" disables size cap
SCRAPE_INTERVAL="${SCRAPE_INTERVAL:-5s}"

# 127.0.0.1 = localhost only (ssh tunnel recommended)
# 0.0.0.0   = accessible from LAN at http://192.168.x.y:\<port\>
BIND_ADDR="${BIND_ADDR:-127.0.0.1}"

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
  local url="$1" tries="${2:-40}" sleep_s="${3:-1}"
  for i in $(seq 1 "$tries"); do
    if curl -fsS --max-time 2 "$url" >/dev/null; then
      return 0
    fi
    sleep "$sleep_s"
  done
  echo "ERROR: timed out waiting for $url"
  return 1
}

fix_env_permissions_for_user() {
  # Option B: readable by the invoking user without making it world-readable
  # Uses the invoking user's primary group (common on Ubuntu: group == username)
  local u="${SUDO_USER:-}"
  if [[ -z "$u" ]]; then return 0; fi
  local g
  g="$(id -gn "$u" 2>/dev/null || true)"
  if [[ -n "$g" ]]; then
    chgrp "$g" "$ENV_FILE" || true
    chmod 640 "$ENV_FILE" || true
  fi
}

ensure_docker_running_socket_activation() {
  log "Ensuring docker.socket + docker.service are started (socket activation)"
  systemctl daemon-reload || true
  systemctl reset-failed docker.service docker.socket || true
  systemctl enable docker.socket docker.service >/dev/null 2>&1 || true

  systemctl stop docker.service docker.socket || true
  rm -f /run/docker.sock /var/run/docker.sock || true

  systemctl start docker.socket
  systemctl start docker.service

  systemctl is-active --quiet docker.socket || { systemctl status docker.socket --no-pager -l || true; exit 1; }
  systemctl is-active --quiet docker.service || { systemctl status docker.service --no-pager -l || true; journalctl -u docker -b --no-pager -l | tail -n 200 || true; exit 1; }
}

main() {
  as_root "$@"

  apt-get update -y
  apt-get install -y ca-certificates curl gnupg openssl python3

  # assume docker/compose already installed on your box now; just ensure it's running
  has_cmd docker || { echo "ERROR: docker not found"; exit 1; }
  docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose not found"; exit 1; }

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

  cat >"$GRAF_DIR/provisioning/datasources/ds.yml" <<'YML'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
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

  if [[ ! -f "$GRAF_DIR/dashboards/dcgm-exporter-dashboard.json" ]]; then
    curl -fsSL -o "$GRAF_DIR/dashboards/dcgm-exporter-dashboard.json" \
      "https://github.com/NVIDIA/dcgm-exporter/raw/main/grafana/dcgm-exporter-dashboard.json"
  fi

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
      - "${BIND_ADDR}:9400:9400"

  node-exporter:
    image: quay.io/prometheus/node-exporter:latest
    restart: unless-stopped
    pid: "host"
    command:
      - "--path.procfs=/host/proc"
      - "--path.sysfs=/host/sys"
      - "--path.rootfs=/rootfs"
      - "--path.udev.data=/rootfs/run/udev/data"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro,rslave
    ports:
      - "${BIND_ADDR}:9100:9100"

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
      - "${BIND_ADDR}:9090:9090"

  grafana:
    image: grafana/grafana-oss:latest
    restart: unless-stopped
    env_file: [ "./.env" ]
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    ports:
      - "${BIND_ADDR}:3000:3000"

volumes:
  prometheus-data:
  grafana-data:
EOF

  log "Starting/refreshing stack"
  cd "$BASE_DIR"
  docker compose -f "$COMPOSE_FILE" up -d

  log "Waiting for endpoints (avoids startup race)"
  wait_http "http://${BIND_ADDR}:9400/metrics" 60 1
  wait_http "http://${BIND_ADDR}:9100/metrics" 60 1
  wait_http "http://${BIND_ADDR}:9090/-/ready" 60 1

  echo
  echo "Grafana:    http://$(hostname -I | awk '{print $1}'):3000   (LAN)   or http://${BIND_ADDR}:3000 (local)"
  echo "Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
  echo "Password:   sudo cat $ENV_FILE"
}
main "$@"
