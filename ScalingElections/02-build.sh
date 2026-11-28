#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd ScalingElections

# v0.2.0's setup.py only finds CUDA in /usr/local/cuda, so this runs the nvcc command its
# compile_cuda() would, and links the same libraries.
python3 -m venv .venv
. .venv/bin/activate
python -m pip install "numpy==1.26.*" "numba==0.60.*" pybind11

read -ra PYBIND_INCS <<<"$(python -m pybind11 --includes)"
NUMPY_INC="$(python -c 'import numpy; print(numpy.get_include())')"
EXT_SUFFIX="$(python -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')"

mkdir -p build
nvcc -ccbin g++ -c scaling_elections.cu -o build/scaling_elections.o -std=c++17 \
    "-gencode=arch=compute_${CUDAARCHS},code=sm_${CUDAARCHS}" \
    "-gencode=arch=compute_${CUDAARCHS},code=compute_${CUDAARCHS}" \
    -Xcompiler -fPIC "${PYBIND_INCS[@]}" -I"${NUMPY_INC}" -O3 -g

g++ -shared build/scaling_elections.o -o "scaling_elections${EXT_SUFFIX}" \
    -L"${CUDA_PATH}/lib64" -L"${CUDA_PATH}/lib" -L"${CUDA_PATH}/lib64/stubs" \
    -lcudart -lcuda -lcublas -fopenmp
