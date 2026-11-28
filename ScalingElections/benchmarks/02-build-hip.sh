#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

cd ScalingElections

# The hipcc command setup.py's compile_hip() runs, and the libraries it links.
python3 -m venv .venv
. .venv/bin/activate
python -m pip install "numpy==1.26.*" "numba==0.60.*" pybind11

read -ra PYBIND_INCS <<<"$(python -m pybind11 --includes)"
NUMPY_INC="$(python -c 'import numpy; print(numpy.get_include())')"
EXT_SUFFIX="$(python -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')"

mkdir -p build
hipcc -c scaling_elections.cu -o build/scaling_elections.o -std=c++17 "--offload-arch=${TEST_GPU_ARCH}" \
    -fPIC "${PYBIND_INCS[@]}" -I"${NUMPY_INC}" -O3 -g -D__HIP_PLATFORM_AMD__

g++ -shared build/scaling_elections.o -o "scaling_elections${EXT_SUFFIX}" \
    -L"${ROCM_PATH}/lib" -Wl,-rpath,"${ROCM_PATH}/lib" -lamdhip64 -lgomp -fopenmp
