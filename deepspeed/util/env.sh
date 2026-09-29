# Source from the test workdir.

source .venv/bin/activate

# See pytorch/04-run-unit_tests.sh.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

# For evoformer_attn; patched by pytorch/01-patch-pytorch.sh.
export CUTLASS_PATH="$(realpath ../)/pytorch/pytorch/third_party/cutlass"

# Build ops fresh each run.
export TORCH_EXTENSIONS_DIR="$(realpath .)/torch_extensions"
export MAX_JOBS="$(nproc)"

# See pytorch/util/build-env.sh.
export TORCH_EXTENSION_SKIP_NVCC_GEN_DEPENDENCIES=1

export PYTHONUNBUFFERED=1
