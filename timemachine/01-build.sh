#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# args.sh sets colour-diagnostics in CXXFLAGS, but timemachine uses
# string concatenation to add `-Wall` with no leading space, and cmake
# provides no way to preserve a trailing space, sooo:
unset CXXFLAGS

mkdir -p "${OUT_DIR}/timemachine/build"
cd "${OUT_DIR}/timemachine/timemachine"
python3.12 -m venv venv
source venv/bin/activate
pip install mypy

pip install -r requirements.txt
CMAKE_ARGS=-DCUDA_ARCH=86 pip install -e .[dev,test]
