#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_DIR}/bin:${PATH}"
export CUDACXX="${CUDA_DIR}/bin/nvcc"
export LD_LIBRARY_PATH="${CUDA_DIR}/lib"

# Configure.
cd "${OUT_DIR}/hashinator/hashinator"
mkdir subprojects
meson wrap install gtest
meson setup -Dwerror=false build --buildtype=release
meson compile -C build --jobs=8
