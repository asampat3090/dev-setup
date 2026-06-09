#!/usr/bin/env bash
#
# setup-docker.sh — Install Docker and NVIDIA Container Toolkit.
#
# Adapts per distro family. GPU toolkit only installed when GPUs present.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# --- Docker ---

log "Setting up Docker..."

if command_exists docker; then
    ok "Docker already installed ($(docker --version 2>/dev/null | awk '{print $3}' | tr -d ','))"
else
    log "Installing Docker..."

    case "$DISTRO_FAMILY" in
        debian)
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL "https://download.docker.com/linux/$DISTRO/gpg" | \
                sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
            sudo chmod a+r /etc/apt/keyrings/docker.gpg

            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/$DISTRO \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            pkg_update
            pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        rhel)
            sudo dnf config-manager --add-repo \
                https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || \
            sudo yum-config-manager --add-repo \
                https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || true

            pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo systemctl enable --now docker 2>/dev/null || true
            ;;
        fedora)
            sudo dnf config-manager --add-repo \
                https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || true

            pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo systemctl enable --now docker 2>/dev/null || true
            ;;
    esac

    ok "Docker installed"
fi

# Add current user to docker group
if ! groups "$USER" | grep -q docker; then
    log "Adding $USER to docker group..."
    sudo usermod -aG docker "$USER"
    ok "Added to docker group (log out and back in to take effect)"
else
    ok "$USER already in docker group"
fi

# --- NVIDIA Container Toolkit (GPU only) ---

if $HAS_GPU; then
    log "Setting up NVIDIA Container Toolkit..."

    if pkg_installed nvidia-container-toolkit; then
        ok "NVIDIA Container Toolkit already installed"
    else
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
            sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null

        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

        # RHEL/Fedora path
        if [ "$DISTRO_FAMILY" != "debian" ]; then
            curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
                sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo > /dev/null
        fi

        pkg_update
        pkg_install nvidia-container-toolkit

        sudo nvidia-ctk runtime configure --runtime=docker > /dev/null 2>&1 || true
        sudo systemctl restart docker 2>/dev/null || true

        ok "NVIDIA Container Toolkit installed"
    fi
else
    log "No GPUs detected — skipping NVIDIA Container Toolkit"
fi

ok "Docker setup complete"
