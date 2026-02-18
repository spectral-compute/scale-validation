#!/bin/bash

set -ETeuo pipefail

# args.sh sets colour-diagnostics in CXXFLAGS, but timemachine uses
# string concatenation to add `-Wall` with no leading space, and cmake
# provides no way to preserve a trailing space, sooo:
unset CXXFLAGS

mkdir -p "build"

cd "timemachine"
python3.12 -m venv venv
source venv/bin/activate
pip install mypy

pip install -r requirements.txt
CMAKE_ARGS=-DCUDA_ARCH=${CUDAARCHS} pip install -e .[dev,test]
cd -
