#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Configure.
args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_CTEST_ARGUMENTS="--output-on-failure --output-junit vllm.xml"
    -DCMAKE_INSTALL_PREFIX="install"

    -DVLLM_PYTHON_EXECUTABLE="$(which python3)"
    -DBUILD_TESTING=ON
)
cmake \
    "${args[@]}" \
    -B"build" \
    "vllm"

make -O -C "build" install -j"$(nproc)"
#
## Build the Python package, and install it.
#cd "${OUT_DIR}/vllm/build/vllm/python"
#python3 -m build --wheel --no-isolation
#python3 -m installer --prefix= --destdir="${OUT_DIR}/vllm/install" dist/*.whl
