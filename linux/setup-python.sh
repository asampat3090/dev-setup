#!/usr/bin/env bash
#
# setup-python.sh — Install Python, pip, venv, and Miniconda.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# --- Python 3 + pip + venv ---

log "Setting up Python..."

pkg_install_mapped python3 python3-pip python3-venv python3-dev

ok "Python $(python3 --version 2>/dev/null | awk '{print $2}') installed"

python3 -m pip install --upgrade pip --quiet 2>/dev/null || \
    python3 -m pip install --upgrade pip --quiet --break-system-packages 2>/dev/null || \
    warn "Could not upgrade pip (non-critical)"

# --- Miniconda ---

log "Checking Miniconda..."

CONDA_DIR="$HOME/miniconda3"

if command_exists conda; then
    ok "conda already installed"
elif [ -f "$CONDA_DIR/bin/conda" ]; then
    ok "conda found at $CONDA_DIR"
else
    log "Installing Miniconda..."
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)  MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" ;;
        aarch64) MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh" ;;
        *)       warn "Unsupported arch $ARCH for Miniconda"; MINICONDA_URL="" ;;
    esac

    if [ -n "$MINICONDA_URL" ]; then
        INSTALLER="/tmp/miniconda-installer.sh"
        curl -fsSL "$MINICONDA_URL" -o "$INSTALLER"
        bash "$INSTALLER" -b -p "$CONDA_DIR"
        rm -f "$INSTALLER"
        ok "Miniconda installed to $CONDA_DIR"
    fi
fi

if [ -f "$CONDA_DIR/bin/conda" ]; then
    eval "$("$CONDA_DIR/bin/conda" shell.bash hook)"

    if ! grep -q "conda initialize" "$HOME/.bashrc" 2>/dev/null; then
        log "Running conda init..."
        "$CONDA_DIR/bin/conda" init bash > /dev/null 2>&1 || true
        ok "conda init done (restart shell to activate)"
    fi
fi

ok "Python setup complete"
