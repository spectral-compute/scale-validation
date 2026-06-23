#!/bin/bash
set -e

cd flash-attention
source .venv/bin/activate

export MAX_JOBS="${MAX_JOBS:-8}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-12.0}"

rm -f .flash-attention-build-ok

case "${TEST_GPU_ARCH}" in
  sm_*|gfx*)
    echo "Building FlashAttention with SCALE for target ${TEST_GPU_ARCH}"
    ;;
  *)
    echo "Unsupported TEST_GPU_ARCH=${TEST_GPU_ARCH}" >&2
    exit 1
    ;;
esac

# Keep real CUDA headers/libs from scaleenv.
export CUDA_HOME="${CUDA_HOME:-${CUDA_PATH:-${CUDA_DIR:-/usr/local/cuda}}}"
export CUDA_PATH="${CUDA_PATH:-$CUDA_HOME}"
export CUDA_ROOT="${CUDA_ROOT:-$CUDA_HOME}"
export CUDA_TOOLKIT_ROOT_PATH="${CUDA_TOOLKIT_ROOT_PATH:-$CUDA_HOME}"

# Force PyTorch extension builds through SCALE, not real NVIDIA nvcc.
export CUDACXX="${CUDA_NVCC_EXECUTABLE:-${CUDACXX:-$(command -v nvcc)}}"
export CUDA_NVCC_EXECUTABLE="$CUDACXX"

# Keep SCALE's -require-scale flags. Do NOT unset them.
echo "CUDA_HOME=$CUDA_HOME"
echo "CUDACXX=$CUDACXX"
echo "NVCC_PREPEND_FLAGS=${NVCC_PREPEND_FLAGS:-}"
echo "NVCC_APPEND_FLAGS=${NVCC_APPEND_FLAGS:-}"
"$CUDACXX" --version || true

python -m pip uninstall -y flash-attn || true

python -m pip install \
  -v \
  --no-build-isolation \
  --no-cache-dir \
  --no-deps \
  . 2>&1 | tee "build.flash-attention.${TEST_GPU_ARCH}.log"

touch .flash-attention-build-ok
