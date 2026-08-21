#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_INSTALL_PREFIX="install"

    -DBUILD_SHARED_LIBS=ON
    -DBUILD_TESTING=ON

    -DCMAKE_CTEST_ARGUMENTS="--output-on-failure --output-junit faiss.xml"
)

cmake \
    "${args[@]}" \
    -B"build" \
    "faiss"

make -O -C "build" install -j"$(nproc)"

(cd "build/faiss/python" &&
    python3 -m build --wheel --no-isolation &&
    python3 -m installer --prefix= --destdir="install" dist/*.whl)
