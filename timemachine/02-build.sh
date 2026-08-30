#!/bin/bash

set -ETeuo pipefail

EXTRA_CMAKE_ARGS=()
if [ "$(basename "$(realpath "$(which nvcc)")")" == "clang" ] ; then
    EXTRA_CMAKE_ARGS+=(
        "-DCMAKE_C_COMPILER=$(realpath "$(which nvcc)")"
        "-DCMAKE_CXX_COMPILER=$(realpath "$(which nvcc)")++"
        "-DCMAKE_CUDA_FLAGS=-rdc=true"
    )
fi

mkdir -p "build"

cd "timemachine"
python3.12 -m venv venv
source venv/bin/activate
pip install mypy

pip install -r requirements.txt
CMAKE_ARGS="-DCUDA_ARCH=${CUDAARCHS} ${EXTRA_CMAKE_ARGS[@]}" pip install -e .[dev,test]
cd -
