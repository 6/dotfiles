#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo $0" >&2
  exit 1
fi

# Try to guess the main non-root user (works when run via sudo)
USERNAME="${SUDO_USER:-}"
if [[ -z "$USERNAME" || "$USERNAME" == "root" ]]; then
  USERNAME="$(logname 2>/dev/null || echo root)"
fi

echo "Using USERNAME=$USERNAME for shell configuration"
echo

echo "==> Updating package lists..."
apt update

echo "==> Installing base packages..."
apt install -y \
  openssh-server \
  zsh \
  unattended-upgrades \
  avahi-daemon \
  ufw \
  memtest86+ \
  ubuntu-drivers-common \
  pciutils \
  nvme-cli \
  curl \
  git \
  lm-sensors \
  smartmontools \
  alsa-utils \
  ffmpeg \
  imagemagick \
  htop \
  direnv

echo "==> Enabling SSH service on boot..."
systemctl enable ssh
systemctl restart ssh

echo "==> Configuring UFW firewall (allowing SSH)..."
ufw allow OpenSSH >/dev/null 2>&1 || ufw allow 22/tcp
ufw --force enable

echo "==> Setting default boot target to multi-user (no GUI)..."
systemctl set-default multi-user.target

echo "==> Disabling sleep / suspend / hibernate..."
for t in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
  systemctl mask "$t" || true
done

echo "==> Disabling *-wait-online services (faster boot)..."
systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true

echo "==> Enabling unattended upgrades..."
tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

echo "==> Setting default shell to zsh for user $USERNAME (if present)..."
if id "$USERNAME" &>/dev/null; then
  chsh -s /usr/bin/zsh "$USERNAME" || {
    echo "Warning: could not change shell for $USERNAME" >&2
  }
else
  echo "Warning: user $USERNAME not found, skipping shell change" >&2
fi

echo
echo "==> Current IP addresses:"
ip -brief address show | awk '$1 != "lo" {print}'

# Try to pick a reasonable primary IP for the SSH snippet
PRIMARY_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
PRIMARY_IP="${PRIMARY_IP:-<YOUR_SERVER_IP>}"

echo
echo "==> Suggested ~/.ssh/config entry for your other machine:"
cat <<EOF
Host insertservername
  Hostname ${PRIMARY_IP}
  User ${USERNAME}
  IdentitiesOnly yes
  IdentityFile ~/.ssh/id_ed25519
EOF

echo
echo "=== Headless base setup done. ==="
echo "Next steps (manual):"
echo "  * Reboot once for shell default to fully apply."
echo "  * Run memtest from GRUB if you want a RAM sanity pass."
echo "  * Ensure both Ethernet connections autoconnect using nmcli."
echo "  * Install NVIDIA drivers manually when ready:"
echo "      sudo ubuntu-drivers autoinstall"
echo "      sudo reboot"
echo "  * Run './doctor-headless.sh' to verify configuration."
echo
echo "=== Zsh ecosystem setup (run as regular user, not root): ==="
echo "  * Oh My Zsh:          sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
echo "  * Powerlevel10k:      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k"
echo "  * zsh-autosuggestions: git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
echo "  * mise:               https://mise.jdx.dev"
echo "  * Run 'p10k configure' to set up your prompt style"
echo "  * Symlink dotfiles:   ln -s ~/dotfiles/.zshrc ~/.zshrc"
