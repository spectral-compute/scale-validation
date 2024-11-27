#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/faiss"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"

# Look for the Python package. These end up in different places on Arch and Ubuntu.
for D in "${OUT_DIR}/faiss/install/lib/python${PY_VER_PATH}/site-packages" \
         "${OUT_DIR}/faiss/install/local/lib/python${PY_VER_PATH}/dist-packages" ; do
    if [ -e "${D}" ] ; then
        export PYTHONPATH="${D}"
        break
    fi
done
if [ -z "${PYTHONPATH:-}" ] ; then
    echo "Could not find built faiss Python package." 1>&2
    exit 1
fi

python3 faiss/benchs/bench_gpu_sift1m.py
