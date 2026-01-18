# Parse and validate the test script's arguments. This script is intended to be sourced.
USAGE=$(cat <<-END

    Usage: $0 WORKDIR PATH_TO_SCALE GPU_ARCHITECTURE [-s] [-v]${USAGE_SUFFIX:-}

    - WORKDIR
        A directory for the script to work in. Compilation results will
        go here.

    - PATH_TO_SCALE
        The path where SCALE is installed.

    - GPU_ARCHITECTURE
        The AMD GPU archiecture to build for, eg "gfx1100".

    Optional:

        - SKIP_N
            Skip the first N test phases

        - STOP_AFTER_N
            Stop after N test phases

    (Pass only \`-check\` to check that all tests are executable and sequentially ordered)

END
)

if [[ $# -lt 3 ]] ; then
    echo "${USAGE}" 1>&2
    exit 1
fi

OUT_DIR="$(realpath "$1")"
if [ "${PARTIAL_PARSE:-}" != "1" ] && [ ! -e "${OUT_DIR}" ] ; then
    echo "Error: Test output directory \"${OUT_DIR}\" does not exist" 1>&2
    exit 1
fi
shift

SCALE_DIR="$(realpath "$1")"
if [ ! -e "${SCALE_DIR}" ] ; then
    echo "Error: directory \"${SCALE_DIR}\" does not exist" 1>&2
    exit 1
fi
shift

INPUT_GPU_ARCH="$1"
if [ ! -e "${SCALE_DIR}/bin/scaleenv" ] ; then
    echo -e "\x1b[33;1mNOTE: \"${SCALE_DIR}\" is not a SCALE installation; using default environment\x1b[m" 1>&2
    GPU_ARCH=$INPUT_GPU_ARCH

    # Export the environment variables that scaleenv would.
    export CUDA_DIR="${SCALE_DIR}"
    export CUDA_HOME="${SCALE_DIR}"
    export CUDA_PATH="${SCALE_DIR}"
    export CUDACXX="${SCALE_DIR}/bin/nvcc"
    export PATH="${SCALE_DIR}/bin:${PATH-}"
    export CUDAARCHS="${GPU_ARCH}"
    export LD_LIBRARY_PATH="${SCALE_DIR}/lib:${LD_LIBRARY_PATH-}"
    export LIBRARY_PATH="${SCALE_DIR}/lib:${LIBRARY_PATH}"
    export CPATH="${SCALE_DIR}/include:${CPATH}"
    export CUDA_BIN_PATH="${SCALE_DIR}/bin"
else
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
fi
shift

# GPU_ARCH: sm_86
# GPU_ARCH_NUM: 86
# GPU_ARCH_DEC: 8.6
GPU_ARCH_NUM=$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')
GPU_ARCH_DEC="${GPU_ARCH_NUM: :-1}"."${GPU_ARCH_NUM: -1}"

if [ "${PARTIAL_PARSE:-}" == "1" ] ; then
    return 0
fi

# Clone and sync submodules for a project.
function do_clone() {
  git clone --recursive --depth 1 --shallow-submodules --branch $3 $2 $1
}

# Slower, but allows random hashes.
function do_clone_hash() {
  git clone --recursive $2 $1
  git -C $1 checkout $3
  git -C $1 submodule update --init --recursive
}

# Extract version from matching version.txt
get_version () {
    local dir=""
    if [[ $# == 1 ]]; then
        dir="$(dirname $0)"
    else
        dir="$2"
    fi
    echo $(cat "$dir/../versions.txt" | grep "$1" | sed "s/$1 //g")
}

PY_VER_PATH=$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1-2) # Like "3.12"
