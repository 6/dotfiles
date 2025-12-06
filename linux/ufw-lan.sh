#!/usr/bin/env bash
set -euo pipefail

# ufw-lan.sh
# Manage a LAN-only UFW allow rule for a given port, auto-detecting your primary subnet.
#
# Commands:
#   apply [PORT]     - reset UFW and apply a safe baseline + allow LAN subnet to PORT
#   add [PORT]       - add LAN allow rule without resetting other rules
#   remove [PORT]    - remove the LAN allow rule for PORT
#   status           - show ufw status
#
# Defaults:
#   PORT=8000
#
# Examples:
#   ./ufw-lan.sh apply
#   ./ufw-lan.sh apply 4000
#   ./ufw-lan.sh add 8000
#   ./ufw-lan.sh remove 8000
#   ./ufw-lan.sh status

DEFAULT_PORT="8000"

die() {
  echo "Error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

validate_port() {
  local port="$1"
  # Check if port is a number
  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    die "Port must be a number, got: $port"
  fi
  # Check if port is in valid range
  if [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
    die "Port must be between 1 and 65535, got: $port"
  fi
}

check_ufw_enabled() {
  if ! sudo ufw status | grep -q "Status: active"; then
    echo "Warning: UFW is not enabled. Rule added but inactive." >&2
    echo "         Enable UFW with: sudo ufw enable" >&2
  fi
}

get_default_iface() {
  ip route show default 0.0.0.0/0 2>/dev/null | awk '{print $5}' | head -n1
}

get_iface_ip_cidr() {
  local iface="$1"
  ip -o -f inet addr show dev "$iface" 2>/dev/null | awk '{print $4}' | head -n1
}

compute_network_cidr() {
  local ip_cidr="$1"
  python3 - <<PY
import ipaddress, sys
try:
    iface = ipaddress.ip_interface("${ip_cidr}")
    print(str(iface.network))
except Exception as e:
    sys.exit(1)
PY
}

detect_lan_cidr() {
  need_cmd ip
  need_cmd python3

  local iface ip_cidr net_cidr
  iface="$(get_default_iface)"
  [[ -n "${iface}" ]] || die "Could not determine default network interface."

  ip_cidr="$(get_iface_ip_cidr "$iface")"
  [[ -n "${ip_cidr}" ]] || die "Could not find IPv4 address on interface: $iface"

  net_cidr="$(compute_network_cidr "$ip_cidr")" || die "Failed to compute network CIDR from: $ip_cidr"

  echo "$iface|$ip_cidr|$net_cidr"
}

ufw_apply_baseline_and_allow() {
  local port="$1"

  echo "Applying baseline UFW rules + LAN allow for port ${port}..."
  sudo ufw --force reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw allow from "$LAN_CIDR" to any port "$port"
  sudo ufw --force enable
}

ufw_add_allow_only() {
  local port="$1"

  check_ufw_enabled
  echo "Adding LAN allow rule for port ${port} (no reset)..."
  sudo ufw allow from "$LAN_CIDR" to any port "$port"
}

ufw_remove_allow() {
  local port="$1"

  echo "Removing LAN allow rule for port ${port}..."
  # Try a few shapes of the rule; ignore failures.
  set +e
  sudo ufw delete allow from "$LAN_CIDR" to any port "$port" >/dev/null 2>&1
  sudo ufw delete allow from "$LAN_CIDR" to any port "$port" proto tcp >/dev/null 2>&1
  sudo ufw delete allow from "$LAN_CIDR" to any port "$port" proto udp >/dev/null 2>&1
  set -e
}

print_detected() {
  echo "Default interface: $IFACE"
  echo "Interface IP/CIDR: $IP_CIDR"
  echo "LAN subnet CIDR:   $LAN_CIDR"
}

usage() {
  cat <<EOF
Usage:
  $0 apply [PORT]
  $0 add [PORT]
  $0 remove [PORT]
  $0 status

Defaults:
  PORT=${DEFAULT_PORT}

Notes:
  - "apply" resets UFW and sets a safe baseline before allowing LAN access to PORT.
  - "add" only adds the rule without resetting existing rules.
  - The LAN subnet is auto-detected from your default IPv4 route.

EOF
}

main() {
  local cmd="${1:-}"
  local port="${2:-$DEFAULT_PORT}"

  case "$cmd" in
    apply|add|remove)
      # Validate port number
      validate_port "$port"
      # Detect LAN CIDR only when needed
      local info
      info="$(detect_lan_cidr)"
      IFACE="${info%%|*}"
      info="${info#*|}"
      IP_CIDR="${info%%|*}"
      LAN_CIDR="${info#*|}"

      print_detected
      echo "Target port:       $port"
      echo

      ;;
  esac

  case "$cmd" in
    apply)
      need_cmd ufw
      ufw_apply_baseline_and_allow "$port"
      echo
      sudo ufw status verbose
      ;;
    add)
      need_cmd ufw
      ufw_add_allow_only "$port"
      echo
      sudo ufw status verbose
      ;;
    remove)
      need_cmd ufw
      ufw_remove_allow "$port"
      echo
      sudo ufw status verbose
      ;;
    status)
      need_cmd ufw
      sudo ufw status verbose
      ;;
    ""|-h|--help|help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
