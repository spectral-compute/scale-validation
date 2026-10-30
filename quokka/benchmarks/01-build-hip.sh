#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Quokka's native HIP backend, for comparison. Only the benchmarked problems are built.
args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER="${ROCM_PATH}/llvm/bin/clang"
    -DCMAKE_CXX_COMPILER="${ROCM_PATH}/llvm/bin/clang++"

    -DAMReX_GPU_BACKEND=HIP
    -DAMReX_AMD_ARCH="${TEST_GPU_ARCH}"
    -DAMReX_SPACEDIM=3

    -DQUOKKA_PYTHON=OFF
    -GNinja
)

cmake "${args[@]}" -B build -S quokka

# problems.txt lines are "<target> <input>".
mapfile -t targets < <(cut -d' ' -f1 "$(dirname "$0")"/problems.txt | sort -u)
ninja -C build "${targets[@]}"
