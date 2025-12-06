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
- Enables GPM (mouse copy/paste in console)
- Sets default boot target to text mode (no GUI)
- Disables sleep/suspend/hibernate
- Switches your default shell to zsh
- Installs Oh My Zsh, Powerlevel10k, and zsh-autosuggestions

### 3) Symlink dotfiles

```bash
cd ~/dotfiles
./install.sh
```

This will use `linux/.p10k.zsh` automatically (no need to run `p10k configure`).

### 4) Reboot

```bash
sudo reboot
```

### 5) Install Homebrew (as your normal user, not root)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install packages:

```bash
brew install git ffmpeg imagemagick direnv
```

Install development tools

- mise: See https://mise.jdx.dev for latest install instructions.
- UV: See https://docs.astral.sh/uv/getting-started/installation/ for installation options.
- Rust: See https://www.rust-lang.org/tools/install for installation via rustup.

---

### Network configuration (netplan)

Ubuntu Server uses netplan for network configuration. **The setup script configures this automatically** — all detected ethernet interfaces get DHCP enabled.

The following is for reference if you need to make manual changes.

**Find your interface names:**

```bash
ip link show
```

Names like `enp10s0` are predictable names based on hardware location:
- `en` = ethernet
- `p10` = PCI bus 10
- `s0` = slot 0

Your interface names will differ based on your motherboard. Use whatever `ip link show` reports.

**View current config:**

```bash
cat /etc/netplan/*.yaml
```

**Example config** (`/etc/netplan/01-netcfg.yaml`):

```yaml
network:
  version: 2
  ethernets:
    enp10s0:
      dhcp4: true      # get IP automatically from router
    enp11s0:
      dhcp4: true
```

- `dhcp4: true` — interface gets IP from your router (most common for home/office)
- For a static IP instead:
  ```yaml
  enp10s0:
    dhcp4: false
    addresses:
      - 192.168.1.100/24
    routes:
      - to: default
        via: 192.168.1.1
    nameservers:
      addresses: [8.8.8.8, 8.8.4.4]
  ```

**Apply changes:**

```bash
sudo netplan apply
```

If something goes wrong, netplan will timeout and revert after 120 seconds. To test first:

```bash
sudo netplan try
```

### Verify system

```bash
sudo ./doctor-headless.sh
```

### SSH convenience

Add this to `~/.ssh/config` on your other machine:

```
# Use 1Password as SSH agent if not already:
Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

Host INSERT_SERVER_NAME
  Hostname <SERVER_IP>
  User <USERNAME>
```

Replace `INSERT_SERVER_NAME` with your preferred alias and `<USERNAME>` with your user.

To get the server IP with `hostname -I`

Then connect with `ssh INSERT_SERVER_NAME`.

Then `exit` and fix terminal compatibility:

```bash
infocmp -x | ssh INSERT_SERVER_NAME "cat > /tmp/ghostty.terminfo"
ssh -t INSERT_SERVER_NAME "sudo tic -x /tmp/ghostty.terminfo && rm /tmp/ghostty.terminfo"
```

If you are confident key-based SSH works, disabling password auth is a good
hardening step.

First, confirm you can log in with your key from your other machine.

Then `ssh` back in and edit SSH config:

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

### Firewall management (UFW)

The setup script enables UFW and allows SSH. To expose additional ports to your LAN only (not the internet), use `linux/ufw-lan.sh`.

This script automatically detects your LAN subnet from your default network interface and manages UFW rules accordingly.

**Available commands:**

```bash
# Reset UFW and apply safe baseline + allow LAN access to port (default: 8000)
./ufw-lan.sh apply
./ufw-lan.sh apply 4000

# Add LAN allow rule without resetting existing rules
./ufw-lan.sh add 8000

# Remove LAN allow rule for a port
./ufw-lan.sh remove 8000

# Show current UFW status
./ufw-lan.sh status
```

**How it works:**

- Auto-detects your primary network interface and LAN subnet (e.g., `192.168.1.0/24`)
- The `apply` command resets UFW to a safe baseline:
  - Denies all incoming connections by default
  - Allows all outgoing connections
  - Allows SSH (port 22)
  - Allows LAN subnet access to your specified port
- The `add` command adds a rule without resetting existing rules
- The `remove` command removes the LAN allow rule for a specific port

**Example workflow:**

```bash
# Start a service on port 8000 and allow LAN access
./ufw-lan.sh apply 8000

# Later, add another port without resetting
./ufw-lan.sh add 9000

# Remove access to port 8000
./ufw-lan.sh remove 8000
```

**Note:** The script only manages IPv4 rules. IPv6 is not configured.

### Memory testing (memtest)

memtest86+ is installed by the setup script.

To run, reboot:

```bash
sudo reboot
```

GRUB menu will appear briefly. Press the down arrow to keep it visible and navigate.

Look for the memtest86+ entry (choose the standard one, not the "serial console" version):

memtest86+

Run at least 1 pass for a sanity check. One pass typically takes 1-3 hours depending on RAM amount. Watch for any red error messages—if you see errors, your RAM has issues. A clean pass shows no errors. Status display: "Pass: 0" is the first pass (0-indexed), "Pass: X%" shows progress through that pass—wait until it reaches 100% to complete one pass. For 2 passes, wait until "Pass: 1" reaches 100%. "Test #N" is the current test number, and "Errors: 0" is what you want.

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

Also enable persistence mode. Rerun this after installing any new GPU: 

```bash
sudo nvidia-smi -pm 1
```

This means faster first use after boot or after long idle. Downside: Slightly higher idle power.

For CUDA development, also install the CUDA toolkit:

```bash
sudo apt install -y nvidia-cuda-toolkit
```

---

## Monitoring Tools

The setup script installs several monitoring tools. Here's when to use each:

### htop — Process monitor

Interactive process viewer. Use for CPU/memory usage by process.

```bash
htop
```

Press `F6` to sort by CPU/MEM, `F9` to kill a process, `q` to quit.

### lm-sensors — Temperature monitoring

Check CPU and motherboard temps.

```bash
# First-time setup (detects available sensors)
sudo sensors-detect   # answer YES to all prompts

# View temperatures
sensors
```

Run `sensors` when diagnosing thermal issues or after changing cooling. Watch for temps above 80°C under load.

### smartmontools — Disk health

Check SSD/HDD health via SMART data. Critical for catching failing drives early.

```bash
# List drives
lsblk

# Quick health check
sudo smartctl -H /dev/nvme0n1    # NVMe
sudo smartctl -H /dev/sda        # SATA

# Full SMART data (wear level, hours, errors)
sudo smartctl -a /dev/nvme0n1
```

Key values to watch:
- **Percentage Used** (NVMe) — SSD wear level
- **Power On Hours** — total runtime
- **Reallocated Sector Count** (SATA) — bad sectors (should be 0)

### iotop — Disk I/O by process

Find what's hammering your disk.

```bash
sudo iotop
```

Press `o` to show only processes doing I/O, `a` for accumulated stats.

### iftop — Network bandwidth

See network usage by connection in real-time.

```bash
sudo iftop
```

Press `t` to cycle display modes, `n` to toggle DNS resolution, `q` to quit.

### ncdu — Disk usage analyzer

Interactive disk space finder. Much faster than `du` for large filesystems.

```bash
ncdu /           # scan entire system
ncdu /home       # scan specific directory
```

Use arrow keys to navigate, `d` to delete, `q` to quit.

### sysstat (sar/iostat) — Historical stats

Collects system performance data over time.

```bash
# CPU stats from today
sar -u

# Memory stats
sar -r

# Disk I/O stats (real-time)
iostat -x 1

# Per-CPU stats
mpstat -P ALL 1
```

Useful for diagnosing issues that happened in the past (check logs in `/var/log/sysstat/`).
