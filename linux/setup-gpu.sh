#!/usr/bin/env bash
#
# setup-gpu.sh — Install NVIDIA drivers, CUDA toolkit, and cuDNN.
#
# Adapts install method per distro family. Safe to re-run.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [ "$GPU_COUNT" -eq 0 ]; then
    log "No GPUs detected — skipping GPU setup"
    exit 0
fi

log "Setting up NVIDIA stack for $GPU_COUNT GPU(s) on $DISTRO..."

# --- NVIDIA drivers ---

if command_exists nvidia-smi; then
    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    ok "NVIDIA driver already installed (version: $DRIVER_VERSION)"
else
    log "Installing NVIDIA drivers..."

    case "$DISTRO_FAMILY" in
        debian)
            pkg_install ubuntu-drivers-common 2>/dev/null || true
            RECOMMENDED=$(sudo ubuntu-drivers devices 2>/dev/null | grep 'recommended' | awk '{print $3}' || true)
            if [ -n "$RECOMMENDED" ]; then
                log "Installing recommended driver: $RECOMMENDED"
                pkg_install "$RECOMMENDED"
            else
                pkg_install nvidia-driver-535
            fi
            ;;
        rhel)
            # EPEL + NVIDIA repo for RHEL-family
            pkg_install epel-release 2>/dev/null || true
            if ! rpm -q nvidia-driver &>/dev/null; then
                RHEL_VER=$(echo "$DISTRO_VERSION" | cut -d. -f1)
                sudo dnf config-manager --add-repo \
                    "https://developer.download.nvidia.com/compute/cuda/repos/rhel${RHEL_VER}/x86_64/cuda-rhel${RHEL_VER}.repo" 2>/dev/null || true
                pkg_install nvidia-driver-latest-dkms 2>/dev/null || \
                    pkg_install nvidia-driver 2>/dev/null || \
                    warn "Auto-install failed — install NVIDIA drivers manually"
            fi
            ;;
        fedora)
            if ! rpm -q akmod-nvidia &>/dev/null; then
                sudo dnf install -y -q \
                    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
                    2>/dev/null || true
                pkg_install akmod-nvidia xorg-x11-drv-nvidia-cuda 2>/dev/null || \
                    warn "Auto-install failed — install NVIDIA drivers manually"
            fi
            ;;
    esac

    ok "NVIDIA driver installed (reboot may be required)"
fi

# --- CUDA toolkit ---

if command_exists nvcc; then
    CUDA_VERSION=$(nvcc --version | grep -oP 'release \K[0-9]+\.[0-9]+')
    ok "CUDA toolkit already installed (version: $CUDA_VERSION)"
else
    log "Installing CUDA toolkit..."

    ARCH="$(uname -m)"

    case "$DISTRO_FAMILY" in
        debian)
            . /etc/os-release
            CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION_ID//./}/${ARCH}"
            [ "$ARCH" = "aarch64" ] && CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION_ID//./}/sbsa"

            CUDA_KEYRING="cuda-keyring_1.1-1_all.deb"
            if ! pkg_installed cuda-keyring; then
                wget -q "$CUDA_REPO_URL/$CUDA_KEYRING" -O "/tmp/$CUDA_KEYRING"
                sudo dpkg -i "/tmp/$CUDA_KEYRING" > /dev/null
                rm -f "/tmp/$CUDA_KEYRING"
                pkg_update
            fi
            pkg_install cuda-toolkit
            ;;
        rhel|fedora)
            # The NVIDIA repo (added during driver install) includes cuda-toolkit
            pkg_install cuda-toolkit 2>/dev/null || \
                warn "CUDA toolkit install failed — add the NVIDIA CUDA repo manually"
            ;;
    esac

    ok "CUDA toolkit installed"
fi

# --- cuDNN ---

log "Checking cuDNN..."

CUDNN_INSTALLED=false
if pkg_installed "libcudnn9-cuda-12" || pkg_installed "libcudnn8" || pkg_installed "libcudnn9"; then
    CUDNN_INSTALLED=true
fi
# RHEL/Fedora package name
if rpm -q libcudnn9-cuda-12 &>/dev/null 2>&1 || rpm -q libcudnn8 &>/dev/null 2>&1; then
    CUDNN_INSTALLED=true
fi

if $CUDNN_INSTALLED; then
    ok "cuDNN already installed"
else
    log "Installing cuDNN..."
    case "$DISTRO_FAMILY" in
        debian)
            pkg_install libcudnn9-cuda-12 libcudnn9-dev-cuda-12 2>/dev/null || \
            pkg_install libcudnn8 libcudnn8-dev 2>/dev/null || \
            warn "cuDNN apt install failed — download from developer.nvidia.com"
            ;;
        rhel|fedora)
            pkg_install libcudnn9-cuda-12 libcudnn9-devel-cuda-12 2>/dev/null || \
            pkg_install libcudnn8 libcudnn8-devel 2>/dev/null || \
            warn "cuDNN install failed — download from developer.nvidia.com"
            ;;
    esac
fi

# --- CUDA environment ---

CUDA_PROFILE_SCRIPT="/etc/profile.d/cuda.sh"
if [ ! -f "$CUDA_PROFILE_SCRIPT" ]; then
    log "Setting up CUDA environment variables..."
    sudo tee "$CUDA_PROFILE_SCRIPT" > /dev/null << 'CUDA_ENV'
if [ -d /usr/local/cuda ]; then
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
CUDA_ENV
    ok "CUDA environment configured in $CUDA_PROFILE_SCRIPT"
fi

if [ -d /usr/local/cuda ]; then
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# --- GPU health check ---

log "GPU status:"
if command_exists nvidia-smi; then
    nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader 2>/dev/null || true
fi

ok "GPU setup complete"
