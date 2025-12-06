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
  build-essential \
  gpm

echo "==> Enabling SSH service on boot..."
systemctl enable ssh
systemctl restart ssh

echo "==> Configuring UFW firewall (allowing SSH)..."
ufw allow OpenSSH >/dev/null 2>&1 || ufw allow 22/tcp
ufw --force enable

echo "==> Enabling GPM (mouse copy/paste in console)..."
systemctl enable gpm
systemctl start gpm

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

USER_HOME=$(eval echo ~$USERNAME)

echo
echo "==> Installing Oh My Zsh as $USERNAME..."
sudo -u "$USERNAME" bash -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' || {
  echo "Warning: Oh My Zsh installation failed" >&2
}

if [[ -d "$USER_HOME/.oh-my-zsh" ]]; then
  echo "==> Installing Powerlevel10k theme..."
  sudo -u "$USERNAME" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$USER_HOME/.oh-my-zsh/custom/themes/powerlevel10k" 2>/dev/null || {
    echo "Powerlevel10k already installed or failed"
  }

  echo "==> Installing zsh-autosuggestions plugin..."
  sudo -u "$USERNAME" git clone https://github.com/zsh-users/zsh-autosuggestions "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" 2>/dev/null || {
    echo "zsh-autosuggestions already installed or failed"
  }
fi

echo
echo "==> Current IP addresses:"
ip -brief address show | awk '$1 != "lo" {print}'

# Try to pick a reasonable primary IP for the SSH snippet
PRIMARY_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
PRIMARY_IP="${PRIMARY_IP:-<YOUR_SERVER_IP>}"

echo
echo "=== Headless base setup done. ==="
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
echo "Next steps:"
echo "  1. Reboot: sudo reboot"
echo "  2. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
echo "  3. Install brew packages: brew install git ffmpeg imagemagick direnv htop"
echo "  4. Symlink dotfiles: cd ~/dotfiles && ./install.sh"
echo "  5. (Optional) Install mise: https://mise.jdx.dev"
echo
echo "Other tasks:"
echo "  * Run memtest from GRUB if you want a RAM sanity pass."
echo "  * Ensure both Ethernet connections autoconnect using nmcli."
echo "  * Install NVIDIA drivers: sudo ubuntu-drivers autoinstall && sudo reboot"
echo "  * Verify config: ./doctor-headless.sh"
