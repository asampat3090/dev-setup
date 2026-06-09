#!/usr/bin/env bash
#
# setup-linux.sh — Bootstrap a Linux server for ML workflows.
#
# Supports Ubuntu, Debian, RHEL/CentOS, Amazon Linux, Fedora.
# Auto-detects distro, GPU presence, and GPU count.
# Idempotent: safe to run multiple times.
#
# Usage:
#   chmod +x setup-linux.sh
#   ./setup-linux.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# --- Distro check ---

log "Detected: $DISTRO $DISTRO_VERSION (family: $DISTRO_FAMILY)"

if [ "$DISTRO_FAMILY" = "unknown" ]; then
    warn "Unsupported distro: $DISTRO"
    warn "Supported: Ubuntu, Debian, RHEL, CentOS, Rocky, AlmaLinux, Amazon Linux, Fedora"
    read -rp "Continue anyway? [y/N] " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
fi

# --- GPU summary ---

if $HAS_GPU; then
    log "Detected $GPU_COUNT NVIDIA GPU(s)"
else
    log "No NVIDIA GPUs detected — installing CPU-only libraries"
fi

# --- System update ---

log "Updating package lists..."
pkg_update

log "Installing system essentials..."
pkg_install_group
pkg_install_mapped \
    curl \
    wget \
    git \
    git-lfs \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    unzip \
    htop \
    tmux \
    tree \
    jq \
    vim

ok "System essentials installed"

# --- Run sub-scripts ---

run_script() {
    local script="$SCRIPT_DIR/$1"
    if [ -f "$script" ]; then
        log "Running $1..."
        bash "$script"
    else
        warn "Script not found: $script"
    fi
}

run_script "setup-python.sh"

if $HAS_GPU; then
    run_script "setup-gpu.sh"
fi

run_script "setup-ml-libs.sh"

if $HAS_GPU && [ "$GPU_COUNT" -gt 1 ]; then
    run_script "setup-multi-gpu.sh"
fi

run_script "setup-docker.sh"

run_script "setup-ssh.sh"
run_script "setup-jupyter.sh"

# --- Summary ---

echo ""
log "========================================="
log "  ML Server Setup Complete"
log "========================================="
echo ""
echo "  Distro:     $DISTRO $DISTRO_VERSION"
if $HAS_GPU; then
    echo "  GPUs:       $GPU_COUNT NVIDIA GPU(s)"
    if command_exists nvidia-smi; then
        echo ""
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || true
        echo ""
    fi
else
    echo "  GPUs:       None (CPU-only mode)"
fi
echo ""
echo "  Installed:"
echo "    - Python $(python3 --version 2>/dev/null | awk '{print $2}') with pip"
echo "    - Core ML libraries (numpy, pandas, scikit-learn, xgboost, lightgbm)"
echo "    - Deep learning (PyTorch, JAX)"
if $HAS_GPU; then
    echo "    - NVIDIA drivers + CUDA toolkit + cuDNN"
    echo "    - GPU-accelerated PyTorch + JAX"
    if [ "$GPU_COUNT" -gt 1 ]; then
        echo "    - Multi-GPU: NCCL, DeepSpeed, Horovod"
    fi
fi
echo "    - Docker (with NVIDIA Container Toolkit if GPU present)"
echo "    - SSH server (configured for Cursor/VS Code Remote SSH)"
echo "    - JupyterLab (systemd service on port 8888)"
echo ""
echo "  Next steps:"
echo "    1. Log out and back in (or run: newgrp docker)"
echo "    2. Verify: python3 -c 'import torch; print(torch.cuda.is_available())'"
if $HAS_GPU; then
    echo "    3. Test GPU: nvidia-smi"
fi
echo "    - Connect via SSH: ssh $(whoami)@\$(hostname -I | awk '{print \$1}')"
echo "    - Open Jupyter: http://\$(hostname -I | awk '{print \$1}'):8888"
echo ""
