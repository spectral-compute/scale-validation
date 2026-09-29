# Source from the test workdir.

source .venv/bin/activate

# See pytorch/04-run-unit_tests.sh.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

# Model parameters
export OPENFOLD_CACHE="${OPENFOLD_CACHE:-$(realpath .)/data}"

# Needed by the deterministic-algorithms tests.
export CUBLAS_WORKSPACE_CONFIG=":4096:8"

# As deepspeed/util/env.sh.
export CUTLASS_PATH="$(realpath ../)/pytorch/pytorch/third_party/cutlass"
export TORCH_EXTENSIONS_DIR="$(realpath .)/torch_extensions"
export TORCH_EXTENSION_SKIP_NVCC_GEN_DEPENDENCIES=1
export MAX_JOBS="$(nproc)"

export PYTHONUNBUFFERED=1
