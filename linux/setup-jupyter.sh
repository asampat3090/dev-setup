#!/usr/bin/env bash
#
# setup-jupyter.sh — Configure Jupyter for remote access.
#
# Sets up JupyterLab to listen on all interfaces with password auth,
# and creates a systemd service so it survives disconnects.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

log "Setting up Jupyter for remote access..."

# --- Verify Jupyter is installed ---

if ! python3 -c "import jupyterlab" 2>/dev/null; then
    log "Installing JupyterLab..."
    pip_install jupyterlab notebook ipykernel ipywidgets
fi

ok "JupyterLab installed"

# --- Generate config ---

JUPYTER_CONFIG_DIR="$HOME/.jupyter"
JUPYTER_CONFIG="$JUPYTER_CONFIG_DIR/jupyter_lab_config.py"

mkdir -p "$JUPYTER_CONFIG_DIR"

if [ -f "$JUPYTER_CONFIG" ]; then
    ok "Jupyter config already exists at $JUPYTER_CONFIG"
else
    log "Generating Jupyter config..."
    python3 -m jupyter lab --generate-config --quiet 2>/dev/null || true

    # If generate-config didn't create it, write manually
    if [ ! -f "$JUPYTER_CONFIG" ]; then
        touch "$JUPYTER_CONFIG"
    fi
fi

# --- Apply remote-access settings ---

apply_jupyter_setting() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}" "$JUPYTER_CONFIG" 2>/dev/null; then
        sed -i "s|^${key}.*|${key} = ${value}|" "$JUPYTER_CONFIG"
    elif grep -q "^# ${key}" "$JUPYTER_CONFIG" 2>/dev/null; then
        sed -i "s|^# ${key}.*|${key} = ${value}|" "$JUPYTER_CONFIG"
    else
        echo "${key} = ${value}" >> "$JUPYTER_CONFIG"
    fi
}

log "Configuring Jupyter for remote access..."

apply_jupyter_setting "c.ServerApp.ip" "'0.0.0.0'"
apply_jupyter_setting "c.ServerApp.port" "8888"
apply_jupyter_setting "c.ServerApp.open_browser" "False"
apply_jupyter_setting "c.ServerApp.allow_remote_access" "True"

# Set a default notebook directory
NOTEBOOK_DIR="$HOME/notebooks"
mkdir -p "$NOTEBOOK_DIR"
apply_jupyter_setting "c.ServerApp.notebook_dir" "'${NOTEBOOK_DIR}'"

ok "Jupyter configured for remote access"

# --- Set password (non-interactive) ---

if [ ! -f "$JUPYTER_CONFIG_DIR/jupyter_server_config.json" ] || \
   ! python3 -c "import json; d=json.load(open('$JUPYTER_CONFIG_DIR/jupyter_server_config.json')); assert d.get('IdentityProvider',{}).get('hashed_password')" 2>/dev/null; then
    log "Setting Jupyter password..."
    echo ""
    echo "  Choose a password for Jupyter (you'll use this in your browser):"
    python3 -c "
from jupyter_server.auth import passwd
import json, os, getpass

pw = getpass.getpass('  Password: ')
hashed = passwd(pw)

config_path = os.path.expanduser('~/.jupyter/jupyter_server_config.json')
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)

config.setdefault('IdentityProvider', {})['hashed_password'] = hashed

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print('  Password set.')
" 2>/dev/null || warn "Password setup failed — run 'jupyter lab password' manually"
    echo ""
else
    ok "Jupyter password already configured"
fi

# --- Install useful kernels ---

log "Registering Python kernel..."
python3 -m ipykernel install --user --name python3 --display-name "Python 3" > /dev/null 2>&1 || true
ok "Python 3 kernel registered"

# --- Install common notebook extensions ---

pip_install \
    nbconvert \
    nbformat \
    jupyterlab-git \
    jupyterlab-lsp \
    python-lsp-server 2>/dev/null || true

ok "Jupyter extensions installed"

# --- systemd service (run as user) ---

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER_DIR/jupyter.service"

mkdir -p "$SYSTEMD_USER_DIR"

if [ -f "$SERVICE_FILE" ]; then
    ok "Jupyter systemd service already exists"
else
    log "Creating Jupyter systemd user service..."

    JUPYTER_BIN=$(which jupyter 2>/dev/null || echo "$HOME/.local/bin/jupyter")
    if [ ! -f "$JUPYTER_BIN" ] && [ -f "$HOME/miniconda3/bin/jupyter" ]; then
        JUPYTER_BIN="$HOME/miniconda3/bin/jupyter"
    fi

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=JupyterLab
After=network.target

[Service]
Type=simple
ExecStart=${JUPYTER_BIN} lab --no-browser
WorkingDirectory=${NOTEBOOK_DIR}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable jupyter.service 2>/dev/null || true
    ok "Jupyter service created"
fi

# Enable lingering so user services run without an active login
sudo loginctl enable-linger "$USER" 2>/dev/null || true

# --- Start Jupyter ---

if systemctl --user is-active --quiet jupyter.service 2>/dev/null; then
    ok "Jupyter already running"
else
    systemctl --user start jupyter.service 2>/dev/null || true
    ok "Jupyter started"
fi

# --- Print access info ---

IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo ""
log "Jupyter ready:"
echo ""
echo "  Direct:      http://${IP_ADDR}:8888"
echo "  SSH tunnel:  ssh -L 8888:localhost:8888 $(whoami)@${IP_ADDR}"
echo "               then open http://localhost:8888"
echo ""
echo "  Manage:"
echo "    systemctl --user status jupyter"
echo "    systemctl --user restart jupyter"
echo "    journalctl --user -u jupyter -f"
echo ""
echo "  Notebooks dir: ${NOTEBOOK_DIR}"
echo ""

# --- Open firewall for Jupyter (optional) ---

if command_exists ufw; then
    if sudo ufw status 2>/dev/null | grep -q "active"; then
        warn "Jupyter port 8888 is NOT opened in UFW by default."
        warn "If you want direct access (not via SSH tunnel), run:"
        warn "  sudo ufw allow 8888/tcp"
    fi
fi

ok "Jupyter setup complete"
