# Parse and validate the test script's arguments. This script is intended to be sourced.

USAGE="Usage: $0 TEST_OUTPUT_DIRECTORY CUDA_INSTALLATION_DIRECTORY GPU_ARCHITECTURE [-s] [-v]${USAGE_SUFFIX:-}"

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

CUDA_DIR="$(realpath "$1")"
if [ ! -e "${CUDA_DIR}" ] ; then
    echo "Error: CUDA installation directory \"${CUDA_DIR}\" does not exist" 1>&2
    exit 1
fi
shift

GPU_ARCH="$1"
if [ ! -e "${CUDA_DIR}/include/cuda.h" ] ; then
    echo "Error: \"${CUDA_DIR}\" is not a CUDA installation directory" 1>&2
    exit 1
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

BUILD_JOBS=$(nproc)
VERBOSE=0
export CXXFLAGS="-fdiagnostics-color=always -Wno-unused-result"
export CFLAGS="-fdiagnostics-color=always -Wno-unused-result"
export CMAKE_COLOR_DIAGNOSTICS=ON

while [[ $# -gt 0 ]] ; do
    case "$1" in
        -s)
            BUILD_JOBS=1
        ;;
        -v)
            VERBOSE=1
        ;;
        *)
            echo "${USAGE}" 1>&2
            exit 1
        ;;
    esac
    shift
done

# Clone and sync submodules for a project.
function do_clone() {
  git clone --recursive $2 $1
  git -C $1 checkout $3
  git -C $1 submodule update --init --recursive
}

PY_VER_PATH=$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1-2) # Like "3.12"
