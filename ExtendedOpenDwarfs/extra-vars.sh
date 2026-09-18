#!/usr/bin/env bash
export LC_ALL=C
export LANG=C

export APP="${EOD_APP:-${TEST_APP:-fft}}"

# Extra variables used by setup-backends script
export BACKEND="${EOD_BACKEND:-${TEST_BACKEND:-cuda}}"
export CUDA_DEV_TARGET="$CUDAARCHS"
if [[ "${SCALE_ENV:-}" == *gfx* ]]; then
    export COMPILER="${EOD_COMPILER:-${TEST_COMPILER:-scale-amd}}"
    export HIP_DEV_TARGET="${SCALE_ENV:-}" # TODO: this smells
else
    export COMPILER="${EOD_COMPILER:-${TEST_COMPILER:-scale-nvidia}}"
fi

if [[ "$COMPILER" == scale-* ]]; then
    export ODW_USE_SCALE=1
fi

# scale-validation injects compiler diagnostic flags globally.
# EOD manages its own flags; keep the harness from poisoning SCALE/AMD builds.
unset CFLAGS
unset CXXFLAGS
unset NVCC_PREPEND_FLAGS
unset NVCC_APPEND_FLAGS
unset CMAKE_COLOR_DIAGNOSTICS
