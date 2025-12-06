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
  pass "unattended-upgrades package installed."
else
  fail "unattended-upgrades package not installed."
fi

# Check config file exists + has our desired toggles
if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
  if grep -q 'Update-Package-Lists "1"' /etc/apt/apt.conf.d/20auto-upgrades && \
     grep -q 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades; then
    pass "20auto-upgrades enables Update-Package-Lists and Unattended-Upgrade."
  else
    fail "20auto-upgrades exists but does not clearly enable auto updates."
  fi
else
  fail "/etc/apt/apt.conf.d/20auto-upgrades not found."
fi

# Check the systemd timer/service state (best-effort; varies by Ubuntu version)
ua_timer_state="$(systemctl is-enabled apt-daily-upgrade.timer 2>/dev/null || echo unknown)"
ua_timer_active="$(systemctl is-active apt-daily-upgrade.timer 2>/dev/null || echo unknown)"
if [[ "$ua_timer_state" == "enabled" ]]; then
  pass "apt-daily-upgrade.timer is enabled."
else
  fail "apt-daily-upgrade.timer is $ua_timer_state (expected enabled)."
fi

# Evidence of recent unattended runs (best-effort)
if [[ -f /var/log/unattended-upgrades/unattended-upgrades.log ]]; then
  last_run="$(grep -E 'Start|Packages that will be upgraded' /var/log/unattended-upgrades/unattended-upgrades.log 2>/dev/null | tail -n 1 || true)"
  if [[ -n "$last_run" ]]; then
    pass "Found unattended-upgrades log activity (recent evidence present)."
  else
    fail "unattended-upgrades log exists but no obvious recent activity lines found."
  fi
else
  fail "unattended-upgrades log not found yet (may be normal on a fresh install)."
fi

# 7. Time synchronization
if command -v timedatectl &>/dev/null; then
  ntp_enabled="$(timedatectl show -p NTP --value 2>/dev/null || echo unknown)"
  ntp_sync="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo unknown)"

  if [[ "$ntp_enabled" == "yes" ]]; then
    pass "NTP is enabled."
  else
    fail "NTP is not enabled (timedatectl NTP=$ntp_enabled)."
  fi

  if [[ "$ntp_sync" == "yes" ]]; then
    pass "Time is synchronized."
  else
    fail "Time not synchronized yet (NTPSynchronized=$ntp_sync). This can be normal right after install."
  fi
else
  fail "timedatectl not available."
fi

# 8. Shell for USERNAME
shell="$(getent passwd "$USERNAME" 2>/dev/null | cut -d: -f7 || echo "")"
if [[ "$shell" == "/usr/bin/zsh" ]]; then
  pass "Default shell for $USERNAME is zsh."
else
  fail "Default shell for $USERNAME is '$shell' (expected /usr/bin/zsh)."
fi

# 9. Avahi for .local hostname
avahi_enabled="$(systemctl is-enabled avahi-daemon 2>/dev/null || echo unknown)"
avahi_active="$(systemctl is-active avahi-daemon 2>/dev/null || echo unknown)"
if [[ "$avahi_enabled" == "enabled" && "$avahi_active" == "active" ]]; then
  pass "avahi-daemon is enabled and active (mDNS .local should work)."
else
  fail "avahi-daemon status: enabled=$avahi_enabled active=$avahi_active."
fi

# 10. NetworkManager connections overview
echo
if command -v nmcli &>/dev/null; then
  echo "NetworkManager connections (NAME:TYPE:AUTOCONNECT:IP4.METHOD):"
  nmcli -t -f NAME,TYPE,AUTOCONNECT,IP4.METHOD connection show || true
  echo "(Check that your wired connections have AUTOCONNECT=yes and IP4.METHOD=auto.)"
else
  echo "[!!] nmcli not found; NetworkManager may not be installed or in use."
fi

# 11. Memtest package presence
echo
if dpkg -s memtest86+ &>/dev/null; then
  pass "memtest86+ package installed (run manually from GRUB for RAM test)."
else
  fail "memtest86+ not installed."
fi

# 12. NVIDIA driver tooling presence + GPU summary (if installed)
echo
if dpkg -s ubuntu-drivers-common &>/dev/null; then
  pass "ubuntu-drivers-common installed."
else
  fail "ubuntu-drivers-common not installed."
fi

if ! command -v nvidia-smi &>/dev/null; then
  fail "nvidia-smi not found (NVIDIA driver likely not installed yet)."
else
  pass "nvidia-smi present."

  # Get structured PCIe info without headers
  # Format: index,name,gen,width
  mapfile -t GPU_LINES < <(nvidia-smi --query-gpu=index,name,pcie.link.gen.current,pcie.link.width.current \
    --format=csv,noheader,nounits 2>/dev/null || true)

  GPU_COUNT="${#GPU_LINES[@]}"

  if [[ "$GPU_COUNT" -eq 0 ]]; then
    fail "No NVIDIA GPUs detected by nvidia-smi."
  else
    # Print standard summary table
    echo
    echo "NVIDIA summary:"
    nvidia-smi || true

    echo
    echo "PCIe link info:"
    nvidia-smi --query-gpu=index,name,pcie.link.gen.current,pcie.link.width.current --format=csv || true

    # Parse widths (strip spaces, expect like 'x16')
    widths=()
    names=()
    gens=()
    indexes=()

    for line in "${GPU_LINES[@]}"; do
      # CSV fields: idx, name, gen, width
      IFS=',' read -r idx name gen width <<<"$line"
      idx="$(echo "$idx" | xargs)"
      name="$(echo "$name" | xargs)"
      gen="$(echo "$gen" | xargs)"
      width="$(echo "$width" | xargs)"

      # width like "x16" -> 16
      wnum="${width#x}"

      indexes+=("$idx")
      names+=("$name")
      gens+=("$gen")
      widths+=("$wnum")
    done

    # Heuristic expectations for your intended workflow:
    # - 1 GPU: expect x16
    # - 2 GPUs: expect both x8 or better
    if [[ "$GPU_COUNT" -eq 1 ]]; then
      if [[ "${widths[0]}" -ge 16 ]]; then
        pass "Single-GPU PCIe width looks ideal (x${widths[0]})."
      else
        fail "Single-GPU PCIe width is x${widths[0]} (expected x16 for your baseline)."
        echo "     Check slot choice, M.2 lane sharing, or BIOS PCIe settings."
      fi

    elif [[ "$GPU_COUNT" -eq 2 ]]; then
      ok=1
      for i in 0 1; do
        if [[ "${widths[$i]}" -lt 8 ]]; then
          ok=0
        fi
      done

      if [[ "$ok" -eq 1 ]]; then
        pass "Dual-GPU PCIe widths look reasonable for bifurcation (x${widths[0]}/x${widths[1]})."
      else
        fail "Dual-GPU PCIe width looks low (x${widths[0]}/x${widths[1]}; expected ~x8/x8)."
        echo "     Check that both GPUs are in CPU-wired slots, not a chipset x4 slot."
      fi

    else
      pass "Multiple GPUs detected ($GPU_COUNT). Review PCIe widths above."
    fi
  fi
fi

# 13. Hardware sensors (CPU temps) + drive health tools
echo
if dpkg -s lm-sensors &>/dev/null; then
  pass "lm-sensors installed."
  echo "Sensor summary (best-effort):"
  sensors 2>/dev/null || echo "[!!] sensors command failed (may need: sudo sensors-detect)"
else
  fail "lm-sensors not installed."
  echo "     Recommendation:"
  echo "       sudo apt install -y lm-sensors"
  echo "       sudo sensors-detect"
fi

echo
if dpkg -s smartmontools &>/dev/null; then
  pass "smartmontools installed (useful for SATA/S.M.A.R.T. health)."
else
  fail "smartmontools not installed (optional)."
  echo "     Recommendation:"
  echo "       sudo apt install -y smartmontools"
fi

if command -v nvme &>/dev/null; then
  pass "nvme-cli present."
else
  fail "nvme-cli not found."
fi

# 14. NVIDIA thermals/power snapshot
echo
if command -v nvidia-smi &>/dev/null; then
  echo "GPU thermals/power snapshot:"
  nvidia-smi --query-gpu=index,name,temperature.gpu,power.draw,power.limit --format=csv 2>/dev/null || true
fi

# 15. fail2ban (optional hardening)
if dpkg -s fail2ban &>/dev/null; then
  f2b_enabled="$(systemctl is-enabled fail2ban 2>/dev/null || echo unknown)"
  f2b_active="$(systemctl is-active fail2ban 2>/dev/null || echo unknown)"

  if [[ "$f2b_enabled" == "enabled" && "$f2b_active" == "active" ]]; then
    pass "fail2ban is installed, enabled, and active."
  else
    fail "fail2ban is installed but not enabled/active (enabled=$f2b_enabled active=$f2b_active)."
    echo "     Recommendation: after confirming key-based SSH access, enable with:"
    echo "       sudo systemctl enable --now fail2ban"
  fi
else
  fail "fail2ban not installed (optional)."
  echo "     Recommendation (optional hardening):"
  echo "       sudo apt install -y fail2ban"
  echo "       sudo systemctl enable --now fail2ban"
fi

# 16. IP addresses + SSH config helper
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
