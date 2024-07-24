#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/faiss/build"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"

ctest --output-on-failure --output-junit faiss.xml -E "MEM_LEAK.ivfflat"
