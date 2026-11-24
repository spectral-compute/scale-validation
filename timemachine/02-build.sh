#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# timemachine launches __global__ templates across translation units, which CUDA
# 13's default hidden visibility and static template stubs break.
# TODO: Check whether a newer upstream release supports CUDA 13, so this can go.
export SCALE_CUDA_VERSION="12.8"

# test.sh sets colour-diagnostics in CXXFLAGS, but timemachine uses
# string concatenation to add `-Wall` with no leading space, and cmake
# provides no way to preserve a trailing space, sooo:
unset CXXFLAGS

mkdir -p "build"

cd "timemachine"
python3.12 -m venv venv
source venv/bin/activate
pip install mypy

pip install -r requirements.txt
CMAKE_ARGS="-DCUDA_ARCH=${CUDAARCHS}" pip install -e ".[dev,test]"
cd -
