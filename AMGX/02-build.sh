#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

OUT_DIR="$(realpath ../)"
if [ ! -e "${OUT_DIR}/openmpi/install" ]; then
    log "Please build the OpenMPI third party project first. Use the same working directory."
    exit 1
fi

# Configure.
if [ -z "$(which scalediag)" ] || scalediag full-driver p2p; then
    log "scalediag did not detect p2p, not using MPI"
    CMAKE_NO_MPI=Off
else
    log "scalediag did detect p2p, using MPI"
    CMAKE_NO_MPI=On
fi

args=(
    -DCMAKE_NO_MPI="${CMAKE_NO_MPI}"

    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCUDA_ARCH="${CUDAARCHS}"
)

cmake \
    "${args[@]}" \
    -B"build" \
    "AMGX"

make -O -C "build" -j"$(nproc)"
