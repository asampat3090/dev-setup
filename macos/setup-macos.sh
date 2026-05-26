#!/usr/bin/env bash
#
# setup-macos.sh — Optional macOS preferences and extra tools.
#
# This script is idempotent: safe to run multiple times.
# It does NOT affect terminal, IDE, or AI configs (use setup.sh for those).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

log()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m OK: %s\033[0m\n' "$*"; }

command_exists() {
    command -v "$1" &>/dev/null
}

# --- Require Homebrew ---

if ! command_exists brew; then
    echo "Homebrew is required. Run setup.sh first, or install manually."
    exit 1
fi

# --- Extra Homebrew formulae ---

log "Installing extra Homebrew formulae..."

FORMULAE=(
    jq
    ripgrep
    fd
    fzf
    tree
    htop
    wget
    gh
    tmux
    docker-compose
)

for formula in "${FORMULAE[@]}"; do
    if brew list "$formula" &>/dev/null; then
        ok "$formula already installed"
    else
        log "Installing $formula..."
        brew install "$formula" || warn "Failed to install $formula (continuing)"
    fi
done

# --- Cask apps ---

log "Installing Homebrew cask apps..."

CASKS=(
    rectangle
    docker
    anaconda
)

for cask in "${CASKS[@]}"; do
    if brew list --cask "$cask" &>/dev/null; then
        ok "$cask already installed"
    else
        log "Installing $cask..."
        brew install --cask "$cask" || warn "Failed to install $cask (continuing)"
    fi
done

# iTerm2: check app existence directly since it may have been installed manually
if [ -d "/Applications/iTerm.app" ] || brew list --cask iterm2 &>/dev/null; then
    ok "iterm2 already installed"
else
    log "Installing iterm2..."
    brew install --cask iterm2 || warn "Failed to install iterm2 (continuing)"
fi

# --- iTerm2 settings ---

log "Configuring iTerm2..."

ITERM2_PREFS_DIR="$REPO_DIR/terminal/iterm2"
ITERM2_PLIST="$ITERM2_PREFS_DIR/com.googlecode.iterm2.plist"

if [ ! -d "/Applications/iTerm.app" ] && ! brew list --cask iterm2 &>/dev/null; then
    warn "iTerm2 is not installed — settings will be pre-configured so they apply on first launch"
    warn "To install manually: brew install --cask iterm2"
fi

if pgrep -x iTerm2 &>/dev/null; then
    warn "iTerm2 is running — quitting it so preferences can be written safely"
    killall iTerm2 2>/dev/null || true
    sleep 2
fi

if [ -f "$ITERM2_PLIST" ]; then
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$ITERM2_PREFS_DIR"
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
    ok "iTerm2 preferences pointed at $ITERM2_PREFS_DIR"
else
    warn "No iTerm2 plist found at $ITERM2_PLIST"
    warn "Export settings from your other machine first: ./terminal/iterm2/export-settings.sh"
fi

# --- Conda init ---

log "Setting up conda..."

CONDA_BIN="/opt/homebrew/anaconda3/bin/conda"

if [ -f "$CONDA_BIN" ]; then
    if grep -q "conda initialize" "$HOME/.zshrc" 2>/dev/null; then
        ok "conda already initialized in .zshrc"
    else
        log "Running conda init zsh..."
        "$CONDA_BIN" init zsh
        ok "conda init done"
    fi
else
    warn "conda not found at $CONDA_BIN — skipping init"
fi

# --- Developer fonts ---

log "Installing developer fonts..."

if brew list --cask font-fira-code &>/dev/null; then
    ok "Fira Code already installed"
else
    brew tap homebrew/cask-fonts 2>/dev/null || true
    brew install --cask font-fira-code || warn "Failed to install Fira Code"
fi

# --- macOS Defaults ---

log "Setting macOS defaults..."

# Finder: show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Finder: default to list view
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Dock: set icon size
defaults write com.apple.dock tilesize -int 48

# Dock: minimize to application
defaults write com.apple.dock minimize-to-application -bool true

# Dock: auto-hide
defaults write com.apple.dock autohide -bool true

# Keyboard: fast key repeat
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Keyboard: disable press-and-hold for character picker (enable key repeat)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Screenshots: save to ~/Desktop/Screenshots
SCREENSHOT_DIR="$HOME/Desktop/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
defaults write com.apple.screencapture location -string "$SCREENSHOT_DIR"

ok "macOS defaults applied"

# --- Restart affected apps ---

log "Restarting Finder and Dock to apply changes..."

killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true

echo ""
log "macOS setup complete!"
echo ""
echo "  Some changes may require a logout/restart to take full effect."
echo ""
