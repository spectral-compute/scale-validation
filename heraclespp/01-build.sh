#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

OUT_DIR=$(realpath ../)
if [ ! -e "${OUT_DIR}/openmpi/install" ]; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CXX_COMPILER=clang++
    -DCMAKE_CUDA_COMPILER=clang++
    -DCMAKE_CXX_STANDARD=20

    -DMPI_HOME="${OUT_DIR}/openmpi/install"
    -DBUILD_TESTING=OFF

    -DKokkos_ARCH_AMPERE86=ON
    -DKokkos_ENABLE_CUDA=ON

    -DNovapp_EOS=PerfectGas
    -DNovapp_GEOM=Cartesian
    -DNovapp_GRAVITY=Uniform
    -DNovapp_NDIM=3
    -DNovapp_SETUP=rayleigh_taylor3d
    -DNovapp_inih_DEPENDENCY_POLICY=EMBEDDED
    -DNovapp_Kokkos_DEPENDENCY_POLICY=EMBEDDED
)

cmake \
    "${args[@]}" \
    -B build \
    "heraclespp"

make -O -C "build" -j"$(nproc)"
