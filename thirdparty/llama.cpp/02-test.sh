#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/llama.cpp/install/bin"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
for F in test-* ; do
    echo "Running test $F"

    case "${F}" in
        test-tokenizer-*-llama)
            ./"${F}" ${OUT_DIR}/llama.cpp/llama.cpp/models/ggml-vocab-llama.gguf
        ;;
        test-tokenizer-*)
            ./"${F}" ${OUT_DIR}/llama.cpp/llama.cpp/models/ggml-vocab-falcon.gguf
        ;;
        *)
            ./"${F}"
        ;;
    esac
done
