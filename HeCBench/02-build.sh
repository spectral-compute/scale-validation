#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

SRC_DIR="$(realpath .)/HeCBench"

# hecbench preset names are "<model>-<target>"; SCALE reuses the CUDA presets
# under a "scale-" prefix. CUDAARCHS is only set for the CUDA-model modes.
case "${TEST_MODE}" in
scale-amd | scale-nvidia) preset="scale-cuda-sm${CUDAARCHS#sm_}" ;;
nvcc-nvidia) preset="cuda-sm${CUDAARCHS#sm_}" ;;
hip-amd) preset="hip-${TEST_GPU_ARCH}" ;;
*)
    echo "Unrecognised test mode: $TEST_MODE" 1>&2
    exit 1
    ;;
esac

[[ "$TEST_TOOLCHAIN" == "hip" ]] ||
    export CUDAFLAGS="-Wno-cuda-implicit-real-arch -Wno-unused-command-line-argument -Wno-write-strings"

python3 "$SRC_DIR/tools/hecbench" --verbose build --preset "$preset"
