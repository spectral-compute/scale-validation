#!/bin/bash

set -e

USAGE=$(cat <<-END

    Usage: $0 WORKDIR PATH_TO_SCALE GPU_ARCHITECTURE TEST_NAME

    - WORKDIR
        A directory for the script to work in. Compilation results will
        go here.

    - PATH_TO_SCALE
        The path where SCALE is installed.

    - GPU_ARCHITECTURE
        The AMD GPU archiecture to build for, eg "gfx1100".

    - TEST_NAME
        The name of one of the test directories in this repo.

END
)

if [[ $# -lt 3 ]] ; then
    echo "${USAGE}" 1>&2
    exit 1
fi

TEST_DIR="$(realpath "$(dirname "$0")")"
OUT_DIR="$(realpath "$1")"
SCALE_DIR="$(realpath "$2")"
INPUT_GPU_ARCH="$3"
TEST="$4"

# The next argument should be a subdirectory of the directory this script is in.
if [ "$TEST" == "util" ] || [ ! -d "${TEST_DIR}/${TEST}" ] ; then
    echo "Unknown test: ${TEST}" 2>&1
    exit 1
fi

rm -rf "${OUT_DIR}/${TEST}"
mkdir -p "${OUT_DIR}/${TEST}"
cd "${OUT_DIR}/${TEST}"

# Activate SCALE or use Nvidia's CUDA.
if [ -e "${SCALE_DIR}/bin/scaleenv" ] ; then
    echo "Using SCALE at ${SCALE_DIR}"
    source "${SCALE_DIR}/bin/scaleenv" $INPUT_GPU_ARCH

    # This also serves to conveniently explode if we accidentially end up using nvidia nvcc.
    export NVCC_PREPEND_FLAGS="-fdiagnostics-color=always"
    export CXXFLAGS="-fdiagnostics-color=always"
    export CFLAGS="-fdiagnostics-color=always"
    export CMAKE_COLOR_DIAGNOSTICS=ON

    # A buildsystem-independent way of avoiding warning spam.
    # These warnings matter, but nvidia ignores them and the torrent makes CI runs
    # overflow the output limit.
    export NVCC_APPEND_FLAGS="-Wno-deprecated-literal-operator -Wno-format -Wno-unknown-warning-option -Wno-ignored-qualifiers -Wno-cuda-wrong-side -Wno-unused-function -Wno-unused-local-typedef -Wno-unused-parameter -Wno-int-conversion -Wno-sign-conversion -Wno-shorten-64-to-32 -Wno-template-id-cdtor -Wno-switch -Wno-vla-cxx-extension -Wno-missing-template-arg-list-after-template-kw -Wno-deprecated-declarations -Wno-c++11-narrowing-const-reference -Wno-typename-missing -Wno-unknown-pragmas -Wno-inconsistent-missing-override -Wno-unused-private-field -Wno-sign-compare -Wno-pessimizing-move -Wno-unused-result -Wno-invalid-constexpr -Wno-unused-but-set-variable -Wno-unused-variable -Wno-unused-value -Wno-implicit-const-int-float-conversion -Wno-pass-failed"
elif [ ! -e "${SCALE_DIR}/bin/nvcc" ] ; then
    echo "${SCALE_DIR} is not a valid SCALE or NVIDIA CUDA installation directory!" 1>&2
    exit 1
else
    echo "Using NVIDIA CUDA at ${SCALE_DIR} (not SCALE)"

    # Set environment variables that scaleenv sets. This exists because scaleenv makes sure all the CUDA environment
    # variables are set. That is helpful to the user of scaleenv (and the projects' build scripts), but they might not
    # be set if not using scaleenv. So this replicates the helpfulness of scaleenv when not using SCALE.
    export CUDA_DIR="${SCALE_DIR}"
    export CUDA_DIR="${SCALE_DIR}"
    export CUDA_HOME="${SCALE_DIR}"
    export CUDA_PATH="${SCALE_DIR}"
    export CUDA_ROOT="${SCALE_DIR}"
    export CUDA_CXX="${SCALE_DIR}/bin/nvcc"
    export CUDACXX="${SCALE_DIR}/bin/nvcc"
    export CUCC="${SCALE_DIR}/bin/nvcc"
    export CUDA_INC_DIR="${SCALE_DIR}/include"
    export PATH="${SCALE_DIR}/bin:${PATH-}"
    export CUDAARCHS="$(echo $INPUT_GPU_ARCH | sed -Ee 's|sm_||g')"
    export LD_LIBRARY_PATH="${SCALE_DIR}/lib64:${LD_LIBRARY_PATH-}"
    export LIBRARY_PATH="${SCALE_DIR}/lib64:${LIBRARY_PATH-}"
    export CPATH="${SCALE_DIR}/include:${CPATH-}"
    export CUDA_BIN_PATH="${SCALE_DIR}/bin"
fi

# Keep the build log comprehensible despite multi-core; build as much as
# possible to maximise info about what we are missing in the log.
export MAKEFLAGS="-O -k"

# Run all the scripts for the test.
set -o errexit
for i in "${TEST_DIR}/${TEST}"/*.sh; do
    echo "--------------- Executing $i ---------------"
    $i
done
