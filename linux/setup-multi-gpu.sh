#!/usr/bin/env bash
#
# setup-multi-gpu.sh — Install distributed/multi-GPU training libraries.
#
# Only runs when 2+ GPUs are detected.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [ "$GPU_COUNT" -lt 2 ]; then
    log "Single GPU detected — skipping multi-GPU setup"
    exit 0
fi

log "Setting up multi-GPU training for $GPU_COUNT GPUs..."

# --- NCCL ---

log "Installing NCCL..."

if pkg_installed libnccl2 || pkg_installed libnccl; then
    ok "NCCL already installed"
else
    case "$DISTRO_FAMILY" in
        debian)
            pkg_install libnccl2 libnccl-dev 2>/dev/null || \
                warn "NCCL apt install failed — PyTorch ships a bundled version"
            ;;
        rhel|fedora)
            pkg_install libnccl libnccl-devel 2>/dev/null || \
                warn "NCCL install failed — PyTorch ships a bundled version"
            ;;
    esac
fi

# --- MPI ---

log "Installing OpenMPI..."

if command_exists mpirun; then
    ok "OpenMPI already installed"
else
    pkg_install_mapped openmpi-bin libopenmpi-dev
    ok "OpenMPI installed"
fi

# --- DeepSpeed ---

log "Installing DeepSpeed..."

pip_install deepspeed

ok "DeepSpeed installed"

# --- Horovod ---

log "Installing Horovod..."

HOROVOD_WITH_PYTORCH=1 HOROVOD_WITH_MPI=1 HOROVOD_GPU_OPERATIONS=NCCL \
    pip_install horovod 2>/dev/null || \
    warn "Horovod build failed — often needs matching CUDA/NCCL/MPI versions"

# --- PyTorch distributed extras ---

log "Installing distributed training tools..."

pip_install fairscale 2>/dev/null || true

# --- Verification ---

log "Multi-GPU configuration:"
echo ""
echo "  GPUs detected:     $GPU_COUNT"
echo "  Topology:"
if command_exists nvidia-smi; then
    nvidia-smi topo -m 2>/dev/null || echo "  (topology query not supported)"
fi
echo ""

python3 << 'VERIFY'
def check(name, import_name=None):
    import_name = import_name or name
    try:
        mod = __import__(import_name)
        version = getattr(mod, '__version__', 'ok')
        print(f'  \033[1;32m✓\033[0m {name:20s} {version}')
    except ImportError:
        print(f'  \033[1;33m⊘\033[0m {name:20s} not installed')

print('  Multi-GPU libraries:')
check('deepspeed')
check('horovod')
check('fairscale')

try:
    import torch.distributed as dist
    print(f'  \033[1;32m✓\033[0m {"torch.distributed":20s} available')
except Exception:
    print(f'  \033[1;31m✗\033[0m {"torch.distributed":20s} not available')

print()
VERIFY

ok "Multi-GPU setup complete"
