# Source from the test workdir.

source .venv/bin/activate

export VLLM_TARGET_DEVICE=cuda
export TORCH_CUDA_ARCH_LIST="${CUDAARCHS:0:-1}.${CUDAARCHS: -1}"
export MAX_JOBS="$(nproc)"

export PYTHONUNBUFFERED=1
