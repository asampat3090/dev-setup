# Dev Environment Setup

Bootstrap a new Mac or Linux cloud server with dev/ML configs.

## Quick Start

```bash
git clone https://github.com/asampat3090/shellConfigs.git ~/code/shell-configs
cd ~/code/shell-configs
chmod +x setup.sh
./setup.sh
```

## What `setup.sh` Does

1. **Terminal** — symlinks `.zshrc`, `.vimrc`, `.vim/`, `.gitconfig`, `.gitignore_global`
2. **Oh My Zsh** — installs if not present
3. **Homebrew** — installs if not present, then installs core formulae (`git`, `node`, `nvm`, `python3`, `vim`)
4. **Vim** — installs Vundle and plugins
5. **Cursor** — checks if installed (manual download from cursor.com)
6. **VS Code** — installs via Homebrew cask if not present
7. **Claude Code** — installs via npm if not present
8. **Claude Code config** — symlinks `settings.json` and global `CLAUDE.md`

Existing files are backed up to `~/.dotfiles-backup/<timestamp>/` before being replaced.

The script is **idempotent** — safe to run multiple times.

## Repo Structure

```
shell-configs/
├── setup.sh                # Main bootstrap script
├── terminal/
│   ├── .zshrc              # Zsh config (oh-my-zsh)
│   ├── .vimrc              # Vim config
│   ├── .vim/               # Vim plugins/runtime
│   ├── .gitconfig          # Git identity & settings
│   ├── .gitignore_global   # Global gitignore
│   └── iterm2/
│       ├── README.md               # iTerm2 export/import guide
│       ├── export-settings.sh      # Export iTerm2 prefs to this folder
│       └── com.googlecode.iterm2.plist  # (generated) iTerm2 settings
├── ide/
│   ├── cursor/
│   │   └── README.md       # Cursor install & setup guide
│   └── vscode/
│       └── README.md       # VS Code install & setup guide
├── ai/
│   ├── README.md           # Claude Code install & setup guide
│   └── .claude/
│       ├── settings.json   # Default model preferences
│       └── CLAUDE.md       # Global instructions for Claude
├── macos/
│   ├── README.md           # Optional macOS setup guide
│   └── setup-macos.sh      # Extra tools & macOS defaults
├── linux/
│   ├── README.md           # Linux ML server setup guide
│   ├── lib.sh              # Distro detection + package manager abstraction
│   ├── setup-linux.sh      # Main entry point (detects distro + hardware)
│   ├── setup-python.sh     # Python 3, pip, Miniconda
│   ├── setup-gpu.sh        # NVIDIA drivers, CUDA, cuDNN
│   ├── setup-ml-libs.sh    # ML/DL Python libraries
│   ├── setup-multi-gpu.sh  # Multi-GPU: NCCL, DeepSpeed, Horovod
│   ├── setup-docker.sh     # Docker CE + NVIDIA Container Toolkit
│   ├── setup-ssh.sh        # SSH server for remote dev (Cursor/VS Code)
│   └── setup-jupyter.sh    # JupyterLab remote access + systemd service
└── legacy/
    └── vimrc.txt           # Old vim config (archived)
```

## Optional: macOS Defaults & Extra Tools

```bash
chmod +x macos/setup-macos.sh
./macos/setup-macos.sh
```

Installs extra tools (`jq`, `ripgrep`, `fzf`, `gh`, `tmux`, etc.), cask apps
(`iTerm2`, `Rectangle`, `Docker`), configures iTerm2 to load saved preferences
from the repo, installs developer fonts, and sets sensible macOS
Finder/Dock/keyboard defaults.

## Linux Cloud Server (ML)

```bash
cd linux
chmod +x *.sh
./setup-linux.sh
```

Sets up a Linux server for machine learning. Auto-detects distro (Ubuntu, Debian, RHEL/CentOS, Amazon Linux, Fedora) and adapts package manager commands. Auto-detects GPU presence and count:

- **CPU-only** — Installs PyTorch/JAX CPU builds, scikit-learn, xgboost, etc.
- **Single GPU** — Adds NVIDIA drivers, CUDA, cuDNN, GPU-accelerated PyTorch/JAX
- **Multi-GPU (2+)** — Adds NCCL, DeepSpeed, Horovod for distributed training
- **SSH** — Configures sshd for Cursor/VS Code Remote SSH access
- **Jupyter** — JupyterLab with remote access, password auth, and a systemd service

See [linux/README.md](linux/README.md) for full details.
