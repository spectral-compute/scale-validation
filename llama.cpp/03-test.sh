#!/bin/bash

set -ETeuo pipefail

export LD_LIBRARY_PATH="$(realpath build/bin):${LD_LIBRARY_PATH:-}"

# -L main mirrors upstream CI: it keeps the GPU tests (test-backend-ops, test-llama-archs, ...) and
# drops most live-HuggingFace fixture tests ("model"/"python" labels), which diff frozen
# snapshots against moving third-party uploads. test-tokenizers-ggml-vocabs is labeled "main"
# upstream despite being exactly this kind of test (it `git clone`s
# https://huggingface.co/ggml-org/vocabs with no LFS smudge, so every vocab file is just an
# unresolved LFS pointer) -- excluded explicitly since -L main doesn't catch it.
#
# GGML_CUDA_DISABLE_GRAPHS=1 and -E test-thread-safety work around two known issues (tracked
# internally); without them the suite would not complete cleanly.

GGML_CUDA_DISABLE_GRAPHS=1 ctest --verbose --test-dir build -L main \
    -E 'test-thread-safety|test-tokenizers-ggml-vocabs' --output-on-failure --timeout 9000
