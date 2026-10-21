# Keep SGLang's and FlashInfer's runtime-compiled kernels in the test workdir,
# rather than ~/.cache/sglang, so each run builds them with its own toolkit.
# Source from the test workdir.

SGLANG_CACHE_DIR="$(realpath .)/cache/sglang"
export SGLANG_CACHE_DIR
export SGLANG_JIT_CACHE_DIR="${SGLANG_CACHE_DIR}/jit"
