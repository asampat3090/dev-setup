#!/usr/bin/env bash
#
# setup-ml-libs.sh — Install ML/DL Python libraries.
#
# Auto-detects GPU and installs CPU-only or CUDA-accelerated versions.
# Distro-agnostic (all installs are via pip except build deps).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# --- System-level build dependencies ---

log "Installing build dependencies for ML libraries..."

pkg_install_mapped \
    libopenblas-dev \
    liblapack-dev \
    libhdf5-dev \
    libffi-dev \
    libssl-dev \
    libjpeg-dev \
    libpng-dev \
    pkg-config \
    cmake \
    gfortran

ok "Build dependencies installed"

# --- Core data science ---

log "Installing core data science libraries..."

pip_install \
    numpy \
    scipy \
    pandas \
    polars \
    matplotlib \
    seaborn \
    plotly \
    scikit-learn \
    scikit-image \
    statsmodels \
    sympy \
    jupyter \
    jupyterlab \
    notebook \
    ipython

ok "Core data science libraries installed"

# --- Traditional ML ---

log "Installing traditional ML libraries..."

pip_install \
    xgboost \
    lightgbm \
    catboost \
    optuna \
    hyperopt \
    shap \
    eli5 \
    imbalanced-learn \
    category_encoders \
    feature-engine

ok "Traditional ML libraries installed"

# --- NLP ---

log "Installing NLP libraries..."

pip_install \
    nltk \
    spacy \
    gensim \
    sentencepiece \
    tokenizers

ok "NLP libraries installed"

# --- Computer Vision ---

log "Installing CV libraries..."

pip_install \
    opencv-python-headless \
    albumentations \
    Pillow

ok "CV libraries installed"

# --- PyTorch ---

log "Installing PyTorch..."

if $HAS_GPU; then
    log "Installing PyTorch with CUDA support..."
    pip_install torch torchvision torchaudio
    ok "PyTorch (CUDA) installed"
else
    log "Installing PyTorch (CPU-only)..."
    pip_install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    ok "PyTorch (CPU) installed"
fi

# --- JAX ---

log "Installing JAX..."

if $HAS_GPU; then
    log "Installing JAX with CUDA support..."
    pip_install "jax[cuda12]"
    ok "JAX (CUDA) installed"
else
    log "Installing JAX (CPU-only)..."
    pip_install jax
    ok "JAX (CPU) installed"
fi

# --- Hugging Face ecosystem ---

log "Installing Hugging Face ecosystem..."

pip_install \
    transformers \
    datasets \
    accelerate \
    evaluate \
    peft \
    trl \
    safetensors

ok "Hugging Face ecosystem installed"

# --- Experiment tracking & MLOps ---

log "Installing MLOps tools..."

pip_install \
    wandb \
    mlflow \
    tensorboard \
    dvc

ok "MLOps tools installed"

# --- Data processing ---

log "Installing data processing tools..."

pip_install \
    pyarrow \
    fastparquet \
    h5py \
    lmdb \
    redis \
    boto3

ok "Data processing tools installed"

# --- Verification ---

log "Verifying installations..."

python3 << 'VERIFY'
checks = []

def check(name, import_name=None):
    import_name = import_name or name
    try:
        mod = __import__(import_name)
        version = getattr(mod, '__version__', 'ok')
        checks.append((name, version, True))
    except ImportError:
        checks.append((name, 'MISSING', False))

check('numpy')
check('pandas')
check('scikit-learn', 'sklearn')
check('xgboost')
check('lightgbm')
check('torch')
check('jax')
check('transformers')

print()
for name, version, ok in checks:
    status = '\033[1;32m✓\033[0m' if ok else '\033[1;31m✗\033[0m'
    print(f'  {status} {name:20s} {version}')
print()

try:
    import torch
    if torch.cuda.is_available():
        print(f'  PyTorch CUDA:  {torch.cuda.get_device_name(0)}')
        print(f'  CUDA version:  {torch.version.cuda}')
    else:
        print('  PyTorch CUDA:  not available (CPU mode)')
except Exception:
    pass

try:
    import jax
    devices = jax.devices()
    gpu_devices = [d for d in devices if d.platform == 'gpu']
    if gpu_devices:
        print(f'  JAX GPUs:      {len(gpu_devices)} device(s)')
    else:
        print('  JAX GPUs:      none (CPU mode)')
except Exception:
    pass

print()
VERIFY

ok "ML libraries setup complete"
