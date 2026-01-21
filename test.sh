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


# TODO: Kill
if [[ "$CI_INSTA_FAIL" == "true" ]] || [[ "$CI_INSTA_FAIL" == "1" ]]; then
    # Some tests insta-fail as a "skip" to save time in CI while still registering the job
    /bin/false
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

# If we're using SCALE, activate it.

if [ -e "${SCALE_DIR}/bin/scaleenv" ] ; then
    # Activate SCALE
    source "${SCALE_DIR}/bin/scaleenv" $INPUT_GPU_ARCH
    GPU_ARCH=sm_${CUDAARCHS}

    export CXXFLAGS="-fdiagnostics-color=always"
    export CFLAGS="-fdiagnostics-color=always"
    export NVCC_PREPEND_FLAGS="-fdiagnostics-color=always"
    export CMAKE_COLOR_DIAGNOSTICS=ON

    # A buildsystem-independent way of avoiding warning spam.
    # These warnings matter, but nvidia ignores them and the torrent makes CI runs
    # overflow the output limit.
    export NVCC_APPEND_FLAGS="-Wno-unknown-warning-option -Wno-unused-function -Wno-int-conversion -Wno-sign-conversion -Wno-shorten-64-to-32 -Wno-template-id-cdtor -Wno-switch -Wno-vla-cxx-extension -Wno-missing-template-arg-list-after-template-kw -Wno-deprecated-declarations -Wno-c++11-narrowing-const-reference -Wno-typename-missing -Wno-unknown-pragmas -Wno-inconsistent-missing-override -Wno-unused-private-field -Wno-sign-compare -Wno-pessimizing-move -Wno-unused-result -Wno-invalid-constexpr -Wno-unused-but-set-variable -Wno-unused-variable -Wno-unused-value -Wno-implicit-const-int-float-conversion -Wno-pass-failed"

else
    echo -e "\x1b[33;1mNOTE: \"${SCALE_DIR}\" is not a SCALE installation; using default environment\x1b[m" 1>&2
    GPU_ARCH=$INPUT_GPU_ARCH

    # Export the environment variables that scaleenv would.
    export CUDA_DIR="${SCALE_DIR}"
    export CUDA_HOME="${SCALE_DIR}"
    export CUDA_PATH="${SCALE_DIR}"
    export CUDACXX="${SCALE_DIR}/bin/nvcc"
    export PATH="${SCALE_DIR}/bin:${PATH-}"
    export CUDAARCHS="${GPU_ARCH}"
fi

# Run all the scripts for the test.
set -o errexit
for i in "${TEST_DIR}/${TEST}"/*; do
    echo "--------------- Executing $i ---------------"
    $i
done
