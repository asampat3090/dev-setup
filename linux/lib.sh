#!/usr/bin/env bash
#
# lib.sh — Shared helpers and distro abstraction layer.
#
# Source this from every sub-script:
#   source "$(dirname "$0")/lib.sh"
#
# Provides:
#   - Logging helpers (log, warn, ok, err)
#   - Distro detection (DISTRO, DISTRO_VERSION, DISTRO_FAMILY)
#   - Package manager abstraction (pkg_update, pkg_install, pkg_installed)
#   - GPU detection (GPU_COUNT, HAS_GPU)
#   - pip wrapper that handles --break-system-packages
#

# Guard against double-sourcing
if [ "${_LIB_SH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || true
fi
_LIB_SH_LOADED=1

# --- Logging ---

log()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m OK: %s\033[0m\n' "$*"; }
err()  { printf '\033[1;31mERR: %s\033[0m\n' "$*" >&2; }

command_exists() {
    command -v "$1" &>/dev/null
}

# --- Distro detection ---

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

detect_distro_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

detect_distro_family() {
    local distro="$1"
    case "$distro" in
        ubuntu|debian|pop|linuxmint)
            echo "debian" ;;
        rhel|centos|rocky|almalinux|ol|amzn)
            echo "rhel" ;;
        fedora)
            echo "fedora" ;;
        *)
            echo "unknown" ;;
    esac
}

DISTRO="$(detect_distro)"
DISTRO_VERSION="$(detect_distro_version)"
DISTRO_FAMILY="$(detect_distro_family "$DISTRO")"

# --- Package manager abstraction ---

pkg_update() {
    case "$DISTRO_FAMILY" in
        debian)
            sudo apt-get update -qq
            ;;
        rhel)
            if command_exists dnf; then
                sudo dnf makecache -q
            else
                sudo yum makecache -q
            fi
            ;;
        fedora)
            sudo dnf makecache -q
            ;;
        *)
            warn "Unknown distro family — skipping package update"
            ;;
    esac
}

pkg_install() {
    case "$DISTRO_FAMILY" in
        debian)
            sudo apt-get install -y -qq "$@" > /dev/null
            ;;
        rhel)
            if command_exists dnf; then
                sudo dnf install -y -q "$@" > /dev/null
            else
                sudo yum install -y -q "$@" > /dev/null
            fi
            ;;
        fedora)
            sudo dnf install -y -q "$@" > /dev/null
            ;;
        *)
            err "Cannot install packages on unknown distro family"
            return 1
            ;;
    esac
}

pkg_installed() {
    case "$DISTRO_FAMILY" in
        debian)
            dpkg -l "$1" 2>/dev/null | grep -q '^ii'
            ;;
        rhel|fedora)
            rpm -q "$1" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Install a group of packages (like build-essential)
pkg_install_group() {
    case "$DISTRO_FAMILY" in
        debian)
            pkg_install build-essential
            ;;
        rhel|fedora)
            if command_exists dnf; then
                sudo dnf groupinstall -y -q "Development Tools" > /dev/null
            else
                sudo yum groupinstall -y -q "Development Tools" > /dev/null
            fi
            ;;
    esac
}

# Map a Debian package name to its equivalent on the current distro
pkg_name() {
    local deb_name="$1"
    if [ "$DISTRO_FAMILY" = "debian" ]; then
        echo "$deb_name"
        return
    fi

    # Debian -> RHEL/Fedora name mappings (only where they differ)
    case "$deb_name" in
        python3-dev)        echo "python3-devel" ;;
        python3-venv)       echo "python3" ;; # venv is bundled on RHEL
        libopenblas-dev)    echo "openblas-devel" ;;
        liblapack-dev)      echo "lapack-devel" ;;
        libhdf5-dev)        echo "hdf5-devel" ;;
        libffi-dev)         echo "libffi-devel" ;;
        libssl-dev)         echo "openssl-devel" ;;
        libjpeg-dev)        echo "libjpeg-turbo-devel" ;;
        libpng-dev)         echo "libpng-devel" ;;
        libopenmpi-dev)     echo "openmpi-devel" ;;
        openmpi-bin)        echo "openmpi" ;;
        apt-transport-https) echo "" ;; # not needed on RHEL
        software-properties-common) echo "" ;; # not needed on RHEL
        *)                  echo "$deb_name" ;;
    esac
}

# Install packages, auto-mapping names for the current distro.
# Skips empty package names (from mappings that don't apply).
pkg_install_mapped() {
    local mapped_pkgs=()
    for pkg in "$@"; do
        local mapped
        mapped="$(pkg_name "$pkg")"
        if [ -n "$mapped" ]; then
            mapped_pkgs+=("$mapped")
        fi
    done
    if [ "${#mapped_pkgs[@]}" -gt 0 ]; then
        pkg_install "${mapped_pkgs[@]}"
    fi
}

# --- GPU detection ---

detect_gpu_count() {
    local count=0

    if command_exists lspci; then
        count=$(lspci | grep -ci 'nvidia' || true)
    fi

    if [ "$count" -eq 0 ] && [ -e /proc/driver/nvidia/gpus ]; then
        count=$(find /proc/driver/nvidia/gpus -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    fi

    echo "$count"
}

GPU_COUNT="${GPU_COUNT:-$(detect_gpu_count)}"
HAS_GPU=false
if [ "$GPU_COUNT" -gt 0 ]; then
    HAS_GPU=true
fi
export GPU_COUNT HAS_GPU

# --- pip wrapper ---

pip_install() {
    python3 -m pip install "$@" --quiet 2>/dev/null || \
    python3 -m pip install "$@" --quiet --break-system-packages 2>/dev/null || \
    warn "Failed to pip install: $*"
}
