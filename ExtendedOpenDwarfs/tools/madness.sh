# Set the many and varied env vars the test script wants.
export APP="${EOD_APP:-${APP:-fft}}"
export BACKEND="${EOD_BACKEND:-${BACKEND:-cuda}}"
export COMPILER="${EOD_COMPILER:-${COMPILER:-scale-amd}}"
export SIZE="${EOD_SIZE:-${SIZE:-tiny}}"
export ITERS="${EOD_ITERS:-${ITERS:-1}}"

if [[ "$COMPILER" == scale-* ]]; then
    export ODW_USE_SCALE=1
fi

export BACKENDS="${BACKEND}"
if [[ "${BACKEND}" != hip ]]; then
    export CUDA_DEV_TARGET="${CUDA_DEV_TARGET:-sm_${CUDAARCHS}}"

    # Eesh, this thing runs scaleenv itself so we have broken the
    # nvidia-vs-scale uniformity :(((
    # Instead of having scaleenv use in the makefiles of the benchmark,
    # we probably should just have the benchmark be written *as cuda*
    # and then invoke it with/without SCALE, like we do for every other
    # test except this one.
    export SCALE_ROOT="${CUDA_PATH}/../../"

    # This is weird, and suggests mistunderstanding of SCALE?
    # Normally the project will just build CUDA, and we'll run their
    # CUDA build in scaleenv to get a SCALE build.
    export OPENCL_INC_DIR="${OPENCL_INC_DIR:-$CUDA_PATH/include}"
    export OPENCL_LIB_DIR="${OPENCL_LIB_DIR:-$CUDA_PATH/lib}"
else
    export HIP_DEV_TARGET="${HIP_DEV_TARGET:-${SCALE_ENV:-}}"
    export OPENCL_INC_DIR="${OPENCL_INC_DIR:-/usr/include}"
    export OPENCL_LIB_DIR="${OPENCL_LIB_DIR:-/usr/lib}"
fi


# scale-validation injects compiler diagnostic flags globally.
# EOD manages its own flags; keep the harness from poisoning SCALE/AMD builds.
unset CFLAGS
unset CXXFLAGS
unset NVCC_PREPEND_FLAGS
unset NVCC_APPEND_FLAGS
unset CMAKE_COLOR_DIAGNOSTICS

export LC_ALL=C
export LANG=C
