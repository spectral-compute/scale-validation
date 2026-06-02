#!/bin/bash
set -ETeuo pipefail
shopt -s nullglob

CUDAARCHS="${CUDAARCHS:-89}"
cudaarch_to_torch_arch() {
    local arch="$1"
    local major="${arch:0:${#arch}-1}"
    local minor="${arch: -1}"
    echo "${major}.${minor}"
}

cd pytorch
source $(dirname $0)/util/common.sh

cd build/pytorch
python setup.py build
python setup.py install --skip-build
