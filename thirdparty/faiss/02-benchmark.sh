#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/faiss"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
PYTHONPATH=install/lib/python${PY_VER_PATH}/site-packages python3 faiss/benchs/bench_gpu_sift1m.py
