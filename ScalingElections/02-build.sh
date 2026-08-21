#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd "ScalingElections"

# 1) Single venv for everything
if [[ ! -d .venv ]]; then
    python3 -m venv .venv
fi

source .venv/bin/activate

python -V
pip -V

# Pin a Numba-compatible stack for Python 3.12
# (Numba 0.60.x ↔ llvmlite 0.43.x ↔ NumPy 1.26.x)
python -m pip install --upgrade pip wheel setuptools
python -m pip install "numpy==1.26.*" "llvmlite==0.43.*" "numba==0.60.*" pybind11

# 2) Normalize CUDA_PATH coming from the suite
RAW_CUDA_PATH="${CUDA_PATH}"

if [[ -x "${RAW_CUDA_PATH}/bin/nvcc" ]]; then
    NORM_CUDA_PATH="${RAW_CUDA_PATH}"
else
    # SCALE-style /install/bin/../targets/gfx1100 → go up two dirs
    NORM_CUDA_PATH="$(cd "${RAW_CUDA_PATH}/../.." && pwd)"
fi

export CUDA_PATH="${NORM_CUDA_PATH}"
export CUDA_HOME="${NORM_CUDA_PATH}"
export PATH="${CUDA_PATH}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_PATH}/lib64:${CUDA_PATH}/lib:${LD_LIBRARY_PATH:-}"

# 3) Target-specific include (avoid /usr/local/cuda clashes)
if [[ "${GPU_ARCH}" == gfx* ]]; then
    if [[ -d "${CUDA_PATH}/targets/${GPU_ARCH}/include" ]]; then
        TARGET_INC="${CUDA_PATH}/targets/${GPU_ARCH}/include"
    else
        TARGET_INC="$(find "${CUDA_PATH}/targets" -maxdepth 1 -type d -name 'gfx*' | head -n1)/include"
    fi
else
    TARGET_INC="${CUDA_PATH}/include"
fi

# Prefer SCALE headers
export CPATH="${TARGET_INC}:${CUDA_PATH}/include:${CPATH:-}"
export CPLUS_INCLUDE_PATH="${CPATH}"

# 4) Python helper vars from THIS venv
PYBIN=python
PYBIND_INC_STR="$($PYBIN -m pybind11 --includes)"
NUMPY_INC="$($PYBIN -c 'import numpy; print(numpy.get_include())')"
EXT_SUFFIX="$($PYBIN -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')"
PY_LDFLAGS="$($PYBIN -c 'import sysconfig; print(sysconfig.get_config_var("LDFLAGS") or "")')"

# 5) Arch flags for SCALE/nvcc
if [[ "${GPU_ARCH}" == sm_* ]]; then
    SM="${GPU_ARCH#sm_}"
    ARCH_FLAGS="-gencode=arch=compute_${SM},code=sm_${SM}"
else
    ARCH_FLAGS="--offload-arch=${GPU_ARCH}"
fi

NVCC="${CUDA_PATH}/bin/nvcc"
BUILD_DIR=build
mkdir -p "${BUILD_DIR}"

OBJ="${BUILD_DIR}/scaling_elections.o"
OUT_SO="scaling_elections${EXT_SUFFIX}"

# log "[build.sh] CUDA_PATH=${CUDA_PATH}"
# log "[build.sh] GPU_ARCH=${GPU_ARCH}"
# log "[build.sh] TARGET_INC=${TARGET_INC}"
# log "[build.sh] ARCH_FLAGS=${ARCH_FLAGS}"
# log "[build.sh] OUT_SO=${OUT_SO}"

# 6) Compile .cu -> .o with SCALE/nvcc
${NVCC} \
    -O3 -std=c++17 \
    -Xcompiler -fPIC \
    "${ARCH_FLAGS}" \
    "${PYBIND_INC_STR}" \
    -I"${NUMPY_INC}" \
    -I"${TARGET_INC}" \
    -c scaling_elections.cu \
    -o "${OBJ}"

# 7) Link .so with host compiler
CXX="${CXX:-g++}"
"${CXX}" -shared "${OBJ}" -o "${OUT_SO}" \
    "${PY_LDFLAGS}" \
    -L"${CUDA_PATH}/lib64" -L"${CUDA_PATH}/lib" \
    -lcudart -lcuda -lcublas \
    -fopenmp

log "[build.sh] built ${SRCDIR}/${OUT_SO}"
