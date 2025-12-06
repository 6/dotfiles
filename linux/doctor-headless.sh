#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo $0 [username]" >&2
  exit 1
fi

USERNAME="${1:-${SUDO_USER:-}}"
if [[ -z "$USERNAME" || "$USERNAME" == "root" ]]; then
  USERNAME="$(logname 2>/dev/null || echo root)"
fi

echo "Headless doctor running for USERNAME=$USERNAME"
echo

pass() { echo -e "[OK]  $*"; }
fail() { echo -e "[!!] $*"; }

# 1. Default boot target
target="$(systemctl get-default || true)"
if [[ "$target" == "multi-user.target" ]]; then
  pass "Default boot target is multi-user.target (no GUI)."
else
  fail "Default boot target is '$target' (expected multi-user.target)."
fi

# 2. SSH service
ssh_enabled="$(systemctl is-enabled ssh 2>/dev/null || echo unknown)"
ssh_active="$(systemctl is-active ssh 2>/dev/null || echo unknown)"
if [[ "$ssh_enabled" == "enabled" && "$ssh_active" == "active" ]]; then
  pass "ssh service is enabled and active."
else
  fail "ssh service status: enabled=$ssh_enabled active=$ssh_active (expected enabled/active)."
fi

# 3. UFW firewall & SSH rule
if command -v ufw &>/dev/null; then
  ufw_status="$(ufw status 2>/dev/null || true)"
  if echo "$ufw_status" | grep -q "Status: active"; then
    if echo "$ufw_status" | grep -Eiq 'OpenSSH|22/tcp'; then
      pass "UFW is active and has an SSH rule."
    else
      fail "UFW is active but no SSH rule detected (check 'ufw status')."
    fi
  else
    fail "UFW does not appear to be active (check 'sudo ufw status')."
  fi
else
  fail "ufw command not found; firewall not configured by script."
fi

# 4. Sleep/suspend/hibernate masked
for t in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
  state="$(systemctl show -p LoadState --value "$t" 2>/dev/null || echo unknown)"
  if [[ "$state" == "masked" ]]; then
    pass "$t is masked (good)."
  else
    fail "$t LoadState=$state (expected masked)."
  fi
done

# 5. Wait-online services disabled
for svc in systemd-networkd-wait-online.service NetworkManager-wait-online.service; do
  enabled_state="$(systemctl is-enabled "$svc" 2>/dev/null || echo "not-present")"
  if [[ "$enabled_state" == "disabled" || "$enabled_state" == "not-present" || "$enabled_state" == "masked" ]]; then
    pass "$svc is not enabled ($enabled_state)."
  else
    fail "$svc is $enabled_state (expected disabled/not-present)."
  fi
done

# 6. Unattended upgrades
if dpkg -s unattended-upgrades &>/dev/null; then
  if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    if grep -q 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades && \
       grep -q 'Update-Package-Lists "1"' /etc/apt/apt.conf.d/20auto-upgrades; then
      pass "Unattended upgrades appear enabled via 20auto-upgrades."
    else
      fail "20auto-upgrades exists but does not clearly enable unattended upgrades."
    fi
  else
    fail "unattended-upgrades installed but /etc/apt/apt.conf.d/20auto-upgrades not found."
  fi
else
  fail "unattended-upgrades package not installed."
fi

# 7. Shell for USERNAME
shell="$(getent passwd "$USERNAME" 2>/dev/null | cut -d: -f7 || echo "")"
if [[ "$shell" == "/usr/bin/zsh" ]]; then
  pass "Default shell for $USERNAME is zsh."
else
  fail "Default shell for $USERNAME is '$shell' (expected /usr/bin/zsh)."
fi

# 8. Avahi for .local hostname
avahi_enabled="$(systemctl is-enabled avahi-daemon 2>/dev/null || echo unknown)"
avahi_active="$(systemctl is-active avahi-daemon 2>/dev/null || echo unknown)"
if [[ "$avahi_enabled" == "enabled" && "$avahi_active" == "active" ]]; then
  pass "avahi-daemon is enabled and active (mDNS .local should work)."
else
  fail "avahi-daemon status: enabled=$avahi_enabled active=$avahi_active."
fi

# 9. NetworkManager connections overview
echo
if command -v nmcli &>/dev/null; then
  echo "NetworkManager connections (NAME:TYPE:AUTOCONNECT:IP4.METHOD):"
  nmcli -t -f NAME,TYPE,AUTOCONNECT,IP4.METHOD connection show || true
  echo "(Check that your wired connections have AUTOCONNECT=yes and IP4.METHOD=auto.)"
else
  echo "[!!] nmcli not found; NetworkManager may not be installed or in use."
fi

# 10. Memtest package presence
echo
if dpkg -s memtest86+ &>/dev/null; then
  pass "memtest86+ package installed (run manually from GRUB for RAM test)."
else
  fail "memtest86+ not installed."
fi

# 11. NVIDIA driver tooling presence + GPU summary (if installed)
echo
if dpkg -s ubuntu-drivers-common &>/dev/null; then
  pass "ubuntu-drivers-common installed."
else
  fail "ubuntu-drivers-common not installed."
fi

if command -v nvidia-smi &>/dev/null; then
  pass "nvidia-smi present."
  echo
  nvidia-smi || true
  echo
  echo "PCIe link info:"
  nvidia-smi --query-gpu=index,name,pcie.link.gen.current,pcie.link.width.current --format=csv || true
else
  fail "nvidia-smi not found (NVIDIA driver likely not installed yet)."
fi

# 12. IP addresses + SSH config helper
echo
echo "IP addresses:"
ip -brief address show | awk '$1 != "lo" {print}'

PRIMARY_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
PRIMARY_IP="${PRIMARY_IP:-<YOUR_SERVER_IP>}"

echo
echo "Suggested ~/.ssh/config entry for your other machine:"
cat <<EOF
Host insertservername
  Hostname ${PRIMARY_IP}
  User ${USERNAME}
  IdentitiesOnly yes
  IdentityFile ~/.ssh/id_ed25519
EOF

echo
echo "Headless doctor completed. Review any [!!] lines above."
