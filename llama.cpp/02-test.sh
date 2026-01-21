#!/bin/bash

set -ETeuo pipefail

for F in install/bin/test-* ; do
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
