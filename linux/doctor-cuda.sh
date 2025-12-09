#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo $0" >&2
  exit 1
fi

echo "CUDA doctor running (root)"
echo

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }

section() { echo; echo "== $* =="; }

# -----------------------------
# System
# -----------------------------
section "System"
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  pass "OS: ${PRETTY_NAME:-unknown}"
fi
kernel="$(uname -r)"
pass "Kernel: $kernel"

if dpkg -s "linux-headers-$kernel" &>/dev/null; then
  pass "Kernel headers installed for running kernel."
else
  warn "Kernel headers missing for $kernel."
  echo "    Install: sudo apt install -y linux-headers-\$(uname -r)"
fi

# -----------------------------
# APT sources (restricted)
# -----------------------------
section "APT sources"
src_file="/etc/apt/sources.list.d/ubuntu.sources"
if [[ -f "$src_file" ]]; then
  comps="$(grep -E '^Components:' "$src_file" | head -n 1 || true)"
  if echo "$comps" | grep -q "restricted"; then
    pass "APT components include restricted."
  else
    warn "APT components may be missing restricted."
  fi
else
  warn "Could not find ubuntu.sources (ok if you use other source files)."
fi

# -----------------------------
# PCIe enumeration
# -----------------------------
section "PCIe enumeration"
if command -v lspci &>/dev/null; then
  nvc="$(lspci | grep -i nvidia || true)"
  if [[ -n "$nvc" ]]; then
    pass "NVIDIA devices present on PCIe:"
    echo "$nvc"
  else
    fail "No NVIDIA devices found via lspci."
  fi
else
  warn "lspci not installed."
  echo "    Install: sudo apt install -y pciutils"
fi

# -----------------------------
# NVIDIA packages (version-agnostic)
# -----------------------------
section "NVIDIA packages"

# List installed driver-ish packages
installed_nvidia_pkgs="$(dpkg -l | awk '/^ii/ && $2 ~ /^nvidia-(driver|headless|kernel|utils)/ {print $2}')"

if [[ -n "$installed_nvidia_pkgs" ]]; then
  pass "Installed NVIDIA-related packages:"
  echo "$installed_nvidia_pkgs"
else
  warn "No obvious NVIDIA driver/headless/utils packages installed."
fi

# Check for any *open* driver flavor installed
if echo "$installed_nvidia_pkgs" | grep -qE 'nvidia-(driver|headless)-[0-9]+.*-open'; then
  pass "Open-kernel-module NVIDIA package appears installed."
else
  warn "Open-kernel-module package not detected."
  echo "    If your GPU generation requires open modules, consider the recommended *-open package."
fi

# Detect installed nvidia-utils version (if any)
utils_pkg="$(dpkg -l | awk '/^ii/ && $2 ~ /^nvidia-utils-[0-9]+$/ {print $2}' | sort -V | tail -n 1 || true)"
if [[ -n "$utils_pkg" ]]; then
  pass "Detected NVIDIA utils package: $utils_pkg"
else
  warn "No nvidia-utils-<version> package found (nvidia-smi may be missing)."
fi

# -----------------------------
# ubuntu-drivers recommendation
# -----------------------------
section "ubuntu-drivers recommendation"
if command -v ubuntu-drivers &>/dev/null; then
  # Extract the recommended line(s) only
  rec="$(ubuntu-drivers devices 2>/dev/null | awk '/recommended/ {print $0}' || true)"
  if [[ -n "$rec" ]]; then
    pass "ubuntu-drivers recommended:"
    echo "$rec"
  else
    warn "Could not parse a recommended driver from ubuntu-drivers."
  fi
else
  warn "ubuntu-drivers not found (package ubuntu-drivers-common)."
fi

# -----------------------------
# Kernel modules
# -----------------------------
section "Kernel modules"

mods="$(lsmod | awk '{print $1}' | grep -E '^(nvidia|nvidia_uvm|nvidia_drm|nvidia_modeset)$' || true)"

if [[ -n "$mods" ]]; then
  pass "NVIDIA kernel modules loaded:"
  echo "$mods"
else
  warn "NVIDIA kernel modules not currently loaded (or lsmod filtering missed them)."
  echo "    If nvidia-smi works and dmesg shows module init, you're fine."
fi

# -----------------------------
# dmesg hints for open-module requirement
# -----------------------------
section "Driver dmesg hints"
dmsg="$(dmesg | grep -i -E "NVRM|nvidia-drm|requires use of the NVIDIA open kernel modules|open kernel" || true)"
if [[ -n "$dmsg" ]]; then
  echo "$dmsg" | tail -n 80
  if echo "$dmsg" | grep -qi "requires use of the NVIDIA open kernel modules"; then
    warn "dmesg indicates your GPU requires NVIDIA open kernel modules."
    echo "    Suggested approach on headless servers:"
    echo "      1) Identify recommended *-open package:"
    echo "         ubuntu-drivers devices"
    echo "      2) Install headless open driver matching recommendation:"
    echo "         sudo apt install -y nvidia-headless-<VER>-open nvidia-utils-<VER>"
  fi
else
  pass "No NVIDIA-related dmesg hints found."
fi

# -----------------------------
# Secure Boot (best-effort)
# -----------------------------
section "Secure Boot (best-effort)"
if command -v mokutil &>/dev/null; then
  sb="$(mokutil --sb-state 2>/dev/null || true)"
  if echo "$sb" | grep -qi "enabled"; then
    warn "Secure Boot appears enabled (can block unsigned modules)."
  elif echo "$sb" | grep -qi "disabled"; then
    pass "Secure Boot appears disabled."
  else
    warn "Could not determine Secure Boot state."
  fi
else
  warn "mokutil not installed (optional)."
fi

# -----------------------------
# nvidia-smi functional + PCIe sanity
# -----------------------------
section "nvidia-smi"
if command -v nvidia-smi &>/dev/null; then
  if nvidia-smi &>/dev/null; then
    pass "nvidia-smi works."
    nvidia-smi || true

    echo
    echo "PCIe link info:"
    nvidia-smi --query-gpu=index,name,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current \
      --format=csv || true

    # Simple lane interpretation
    mapfile -t LINES < <(nvidia-smi --query-gpu=index,pcie.link.width.current \
      --format=csv,noheader,nounits 2>/dev/null || true)

    widths=()
    for line in "${LINES[@]}"; do
      IFS=',' read -r idx width <<<"$line"
      width="$(echo "$width" | xargs)"
      widths+=("${width#x}")
    done

    count="${#widths[@]}"
    if [[ "$count" -eq 1 ]]; then
      if [[ "${widths[0]:-0}" -ge 16 ]]; then
        pass "Single-GPU lane width looks ideal (x${widths[0]})."
      else
        warn "Single-GPU lane width is x${widths[0]} (baseline often expected x16)."
      fi
    elif [[ "$count" -eq 2 ]]; then
      if [[ "${widths[0]:-0}" -ge 8 && "${widths[1]:-0}" -ge 8 ]]; then
        pass "Dual-GPU lane widths look reasonable (x${widths[0]}/x${widths[1]})."
      else
        warn "Dual-GPU lane widths look low (x${widths[0]}/x${widths[1]})."
      fi
    else
      pass "Detected $count GPUs. Review PCIe widths above."
    fi

  else
    fail "nvidia-smi present but not functioning."
    echo "    Check dmesg hints above; you may need the *-open driver flavor."
  fi
else
  warn "nvidia-smi not found."
  echo "    Install the matching nvidia-utils package for your driver series."
fi

# -----------------------------
# CUDA toolkit + nvcc wiring
# -----------------------------
section "CUDA toolkit"
if ls -d /usr/local/cuda-* &>/dev/null; then
  pass "Found CUDA toolkit directories:"
  ls -d /usr/local/cuda-* | sort -V
else
  warn "No /usr/local/cuda-* directories found."
fi

if [[ -L /usr/local/cuda || -d /usr/local/cuda ]]; then
  pass "/usr/local/cuda exists:"
  ls -l /usr/local/cuda
else
  warn "/usr/local/cuda not found (symlink recommended)."
fi

section "nvcc"
if command -v nvcc &>/dev/null; then
  pass "nvcc found at: $(command -v nvcc)"
  nvcc --version || true
else
  warn "nvcc not found in PATH."
  echo "    If you installed cuda-toolkit, consider:"
  echo "      sudo ln -sfn /usr/local/cuda-<VERSION> /usr/local/cuda"
  echo "      sudo ln -sfn /usr/local/cuda/bin/nvcc /usr/bin/nvcc"
fi

if [[ -L /usr/bin/nvcc || -f /usr/bin/nvcc ]]; then
  pass "/usr/bin/nvcc exists."
else
  warn "/usr/bin/nvcc missing (some build tools expect it here)."
fi

# -----------------------------
# Library visibility
# -----------------------------
section "CUDA libraries"
if command -v ldconfig &>/dev/null; then
  if ldconfig -p | grep -qi "libcuda.so"; then
    pass "libcuda.so present in dynamic linker cache."
  else
    warn "libcuda.so not found via ldconfig."
  fi

  if ldconfig -p | grep -qi "libcudart.so"; then
    pass "libcudart.so present in dynamic linker cache."
  else
    warn "libcudart.so not found via ldconfig."
  fi
fi

echo
echo "Doctor-cuda completed."
