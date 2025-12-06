# Ubuntu Server Headless Setup 

This directory contains a deterministic setup + verification flow.

It assumes you enabled OpenSSH during install and imported your
existing SSH public key from GitHub when the installer offered it.

---

## Repo layout

- `linux/setup-headless.sh` — baseline config + packages
- `linux/doctor-headless.sh` — sanity checker

---

## Quick start

### 0) Fixing tiny console text (local monitor)

On Ubuntu Server, this is usually the TTY console font.

Run this:

```bash
sudo dpkg-reconfigure console-setup
```

1. Choose `UTF-8`
2. Guess optimal character set
3. Terminus
4. Choose largest size: 16x32

```bash
sudo reboot
```

### 1) Clone the dotfiles repo

Login. Then run:

```bash
cd ~
git clone https://github.com/6/dotfiles.git
cd dotfiles/linux
```

### 2) Run the setup script

```
sudo ./setup-headless.sh
```

What this does:

- Installs system packages (openssh-server, zsh, ufw, gpm, etc.)
- Enables SSH and configures UFW firewall
- Enables GPM (mouse support in console)
- Sets default boot target to text mode (no GUI)
- Disables sleep/suspend/hibernate
- Switches your default shell to zsh
- Installs Oh My Zsh, Powerlevel10k, and zsh-autosuggestions

### 3) Install Homebrew (as your normal user, not root)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the instructions to add brew to your PATH, then:

```bash
brew install git ffmpeg imagemagick direnv htop
```

### 4) Reboot

```bash
sudo reboot
```

### 5) Symlink dotfiles

```bash
cd ~/dotfiles
./install.sh
```

This will use `linux/.p10k.zsh` automatically (no need to run `p10k configure`).

### 6) (Optional) Install mise

See https://mise.jdx.dev for latest install instructions.

---

### Network autoconnect

Ensure both Ethernet connections autoconnect:

```bash
nmcli device status
nmcli connection show

# adjust connection names as needed
nmcli connection modify "Wired connection 1" connection.autoconnect yes ipv4.method auto
nmcli connection modify "Wired connection 2" connection.autoconnect yes ipv4.method auto
```

### Verify system

```bash
sudo ./doctor-headless.sh
```

### SSH convenience

Follow instructions to modify ~/.ssh/config on other computer so you can login with `ssh insertservername`.

If you are confident key-based SSH works, disabling password auth is a good
hardening step.

First, confirm you can log in with your key from your other machine.

Edit SSH config:

```bash
sudo nano /etc/ssh/sshd_config
```


Set or add:

```bash
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
```

Reload SSH:

```bash
sudo systemctl reload ssh
```

### Memory testing (memtest)

memtest86+ is installed by the setup script.

To run, reboot:

```bash
sudo reboot
```

Repeatedly tap Esc to get to GRUB. In GRUB, look for:

memtest86+

Run at least 1 pass for a sanity check.

On some UEFI systems the memtest GRUB entry may not appear reliably.
If you don’t see it, consider a dedicated MemTest USB if you need a full
offline validation.

What to run (reasonable “server sanity”)

Baseline confidence: ✅ 2 full passes

High confidence (recommended for new RAM you’ll stress hard): ✅ 4 passes

### NVIDIA drivers (single-GPU baseline)

When you are ready to install the NVIDIA driver:

```bash
sudo apt update
sudo ubuntu-drivers autoinstall
sudo reboot
```

Verify:

```bash
nvidia-smi
nvidia-smi --query-gpu=name,pcie.link.gen.current,pcie.link.width.current --format=csv
```

This is useful for confirming your single-GPU x16 + Gen5 baseline before adding a
second GPU.