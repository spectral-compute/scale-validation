#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

LD_LIBRARY_PATH="$(realpath build/bin):${LD_LIBRARY_PATH:-}"
export LD_LIBRARY_PATH

# Without a GPU, ggml registers only the CPU backend, which test-backend-ops skips while still
# reporting success, so a runner that has lost its GPU would pass the suite having tested nothing.
devices="$(./install/bin/llama-bench --list-devices)"
echo "${devices}"
echo "${devices}" | grep -q 'CUDA'

# -L main mirrors upstream CI: it keeps the GPU tests (test-backend-ops, test-llama-archs, ...) and
# drops only the live-HuggingFace fixture tests ("model"/"python" labels), which diff frozen
# snapshots against moving third-party uploads.
#
# GGML_CUDA_DISABLE_GRAPHS=1 and -E test-thread-safety work around two known issues (tracked
# internally); without them the suite would not complete cleanly.
GGML_CUDA_DISABLE_GRAPHS=1 ctest --verbose --test-dir build -L main -E test-thread-safety --output-on-failure --timeout 9000
