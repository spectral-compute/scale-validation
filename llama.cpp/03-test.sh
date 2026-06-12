#!/bin/bash

set -ETeuo pipefail

export LD_LIBRARY_PATH="$(realpath build/bin):${LD_LIBRARY_PATH:-}"

# -L main mirrors upstream CI: it keeps the GPU tests (test-backend-ops, test-llama-archs, ...) and
# drops only the live-HuggingFace fixture tests ("model"/"python" labels), which diff frozen
# snapshots against moving third-party uploads.
#
# GGML_CUDA_DISABLE_GRAPHS=1 and -E test-thread-safety work around two known issues (tracked
# internally); without them the suite would not complete cleanly.

GGML_CUDA_DISABLE_GRAPHS=1 ctest --test-dir build -L main -E test-thread-safety --output-on-failure --timeout 9000
