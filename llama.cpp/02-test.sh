#!/bin/bash

set -ETeuo pipefail

SRC_DIR=$(realpath llama.cpp)
for F in install/bin/test-* ; do
    echo "Running test $F"

    case "${F}" in
        test-tokenizer-*-llama)
            ./"${F}" ${SRC_DIR}/models/ggml-vocab-llama.gguf
        ;;
        test-tokenizer-*)
            ./"${F}" ${SRC_DIR}/models/ggml-vocab-falcon.gguf
        ;;
        *)
            ./"${F}"
        ;;
    esac
done
