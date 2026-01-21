#!/bin/bash

set -e

# Look for the Python package. These end up in different places on Arch and Ubuntu.

PY_VER_PATH=$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1-2) # Like "3.12"
for D in "install/lib/python${PY_VER_PATH}/site-packages" \
         "install/local/lib/python${PY_VER_PATH}/dist-packages" ; do
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
