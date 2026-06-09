# Linux Server — ML Setup

Bootstrap a Linux cloud server for machine learning workflows (traditional ML + deep learning).

Supports **Ubuntu**, **Debian**, **RHEL/CentOS/Rocky/AlmaLinux**, **Amazon Linux**, and **Fedora**. Auto-detects distro and adapts package manager commands accordingly.

## Quick Start

```bash
git clone <this-repo> ~/dev-setup
cd ~/dev-setup/linux
chmod +x *.sh
./setup-linux.sh
```

## How It Works

A shared `lib.sh` abstracts the package manager:

| Distro family | Package manager | Distros |
|---|---|---|
| Debian | `apt-get` | Ubuntu, Debian, Pop!_OS, Linux Mint |
| RHEL | `dnf` / `yum` | RHEL, CentOS, Rocky, AlmaLinux, Amazon Linux |
| Fedora | `dnf` | Fedora |

Package names are auto-mapped (e.g. `libssl-dev` -> `openssl-devel` on RHEL). Python ML libraries install via pip, which is distro-agnostic.

## What It Installs

### Always (CPU + GPU)

| Category | Libraries |
|---|---|
| **Core data science** | numpy, scipy, pandas, polars, matplotlib, seaborn, plotly, scikit-learn, jupyter |
| **Traditional ML** | xgboost, lightgbm, catboost, optuna, hyperopt, shap, imbalanced-learn |
| **Deep learning** | PyTorch (CPU or CUDA), JAX (CPU or CUDA) |
| **NLP** | spacy, nltk, gensim, sentencepiece, tokenizers |
| **Computer vision** | opencv, albumentations, Pillow |
| **Hugging Face** | transformers, datasets, accelerate, peft, trl |
| **MLOps** | wandb, mlflow, tensorboard, dvc |
| **Python** | Python 3, pip, venv, Miniconda |
| **Docker** | Docker CE + Docker Compose |
| **SSH** | OpenSSH server configured for Cursor/VS Code Remote SSH |
| **Jupyter** | JupyterLab with remote access, systemd service, password auth |

### GPU Servers (auto-detected)

| Category | What |
|---|---|
| **NVIDIA drivers** | Auto-selects recommended driver per distro |
| **CUDA toolkit** | Latest from NVIDIA apt/dnf repo |
| **cuDNN** | Installed via package manager |
| **NVIDIA Container Toolkit** | GPU access inside Docker containers |

### Multi-GPU Servers (2+ GPUs, auto-detected)

| Category | What |
|---|---|
| **NCCL** | NVIDIA collective communication |
| **DeepSpeed** | Distributed training + inference |
| **Horovod** | MPI-based distributed training |
| **fairscale** | PyTorch distributed training utilities |

## Scripts

| Script | Purpose |
|---|---|
| `lib.sh` | Shared helpers — distro detection, package manager abstraction, GPU detection |
| `setup-linux.sh` | Main entry point — detects hardware, runs sub-scripts |
| `setup-python.sh` | Python 3, pip, venv, Miniconda |
| `setup-gpu.sh` | NVIDIA drivers, CUDA, cuDNN (GPU only) |
| `setup-ml-libs.sh` | All ML/DL Python libraries |
| `setup-multi-gpu.sh` | NCCL, DeepSpeed, Horovod (2+ GPUs only) |
| `setup-docker.sh` | Docker CE + NVIDIA Container Toolkit |
| `setup-ssh.sh` | SSH server for Cursor/VS Code Remote SSH |
| `setup-jupyter.sh` | JupyterLab remote access + systemd service |

## Hardware Detection

The scripts auto-detect:

- **Distro + family** — Maps to correct package manager and package names
- **GPU presence** — Uses `lspci` and `/proc/driver/nvidia`
- **GPU count** — Installs multi-GPU libraries only when 2+ GPUs are found
- **Architecture** — Supports both x86_64 and aarch64

## Verification

After setup, verify:

```bash
# Check Python + core libs
python3 -c "import torch; print(f'PyTorch: {torch.__version__}')"
python3 -c "import sklearn; print(f'scikit-learn: {sklearn.__version__}')"

# Check GPU (if present)
nvidia-smi
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
python3 -c "import torch; print(f'GPU count: {torch.cuda.device_count()}')"

# Check Docker
docker run --rm hello-world
# With GPU:
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi

# Check SSH
systemctl status sshd   # or ssh on Ubuntu

# Check Jupyter
systemctl --user status jupyter
curl http://localhost:8888
```
