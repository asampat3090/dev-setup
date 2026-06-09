#!/usr/bin/env bash
#
# setup-ssh.sh — Configure SSH server for remote development.
#
# Ensures sshd is running and configured for Cursor/VS Code Remote SSH.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

log "Setting up SSH server..."

# --- Install OpenSSH server ---

if command_exists sshd || systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
    ok "SSH server already running"
else
    log "Installing OpenSSH server..."
    case "$DISTRO_FAMILY" in
        debian)
            pkg_install openssh-server
            ;;
        rhel|fedora)
            pkg_install openssh-server
            ;;
    esac
fi

# --- Enable and start sshd ---

SERVICE_NAME="sshd"
if systemctl list-units --type=service 2>/dev/null | grep -q "ssh.service"; then
    SERVICE_NAME="ssh"
fi

sudo systemctl enable "$SERVICE_NAME" 2>/dev/null || true
sudo systemctl start "$SERVICE_NAME" 2>/dev/null || true
ok "SSH service ($SERVICE_NAME) enabled and running"

# --- Configure for remote dev ---

SSHD_CONFIG="/etc/ssh/sshd_config"

apply_sshd_setting() {
    local key="$1"
    local value="$2"

    if grep -qE "^${key}\s+${value}$" "$SSHD_CONFIG" 2>/dev/null; then
        return 0
    fi

    if grep -qE "^#?\s*${key}\s" "$SSHD_CONFIG" 2>/dev/null; then
        sudo sed -i "s/^#*\s*${key}\s.*/${key} ${value}/" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" | sudo tee -a "$SSHD_CONFIG" > /dev/null
    fi
}

log "Configuring sshd for remote development..."

# Keep connections alive (Cursor/VS Code need this)
apply_sshd_setting "ClientAliveInterval" "60"
apply_sshd_setting "ClientAliveCountMax" "10"

# Allow TCP forwarding (needed for Jupyter port forwarding)
apply_sshd_setting "AllowTcpForwarding" "yes"

# Allow agent forwarding (useful for git operations)
apply_sshd_setting "AllowAgentForwarding" "yes"

ok "sshd configured"

# --- Reload sshd to pick up changes ---

sudo systemctl reload "$SERVICE_NAME" 2>/dev/null || \
    sudo systemctl restart "$SERVICE_NAME" 2>/dev/null || true

# --- SSH key convenience ---

if [ ! -f "$HOME/.ssh/authorized_keys" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    warn "No SSH keys found. Add your public key:"
    warn "  echo 'your-public-key' >> ~/.ssh/authorized_keys"
fi

# --- Firewall ---

if command_exists ufw; then
    if sudo ufw status 2>/dev/null | grep -q "active"; then
        sudo ufw allow ssh > /dev/null 2>&1 || true
        ok "UFW: SSH allowed"
    fi
elif command_exists firewall-cmd; then
    if sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
        sudo firewall-cmd --permanent --add-service=ssh > /dev/null 2>&1 || true
        sudo firewall-cmd --reload > /dev/null 2>&1 || true
        ok "firewalld: SSH allowed"
    fi
fi

# --- Print connection info ---

IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
SSH_PORT=$(grep -E "^Port " "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' || echo "22")

echo ""
log "SSH ready. Connect with:"
echo "  ssh $(whoami)@${IP_ADDR} -p ${SSH_PORT}"
echo ""
echo "  For Cursor/VS Code Remote SSH, add to ~/.ssh/config on your Mac:"
echo ""
echo "  Host ml-server"
echo "    HostName ${IP_ADDR}"
echo "    User $(whoami)"
echo "    Port ${SSH_PORT}"
echo "    ForwardAgent yes"
echo ""

ok "SSH setup complete"
