# Set the many and varied env vars the test script wants.
export HOST="${HOST:-$(hostname -s)}"
export BACKENDS="cuda"
export CUDA_DEV_TARGET="${CUDA_DEV_TARGET:-sm_${CUDAARCHS}}"

# This is weird, and suggests mistunderstanding of SCALE?
# Normally the project will just build CUDA, and we'll run their
# CUDA build in scaleenv to get a SCALE build.
export HIP_DEV_TARGET="${HIP_DEV_TARGET:-${SCALE_ENV}}"
export MACHINE="${HOST}"
export OPENCL_INC_DIR="${OPENCL_INC_DIR:-$CUDA_PATH/include}"
export OPENCL_LIB_DIR="${OPENCL_LIB_DIR:-$CUDA_PATH/lib}"

# Eesh, this thing runs scaleenv itself so we have broken the
# nvidia-vs-scale uniformity :(((
# Instead of having scaleenv use in the makefiles of the benchmark,
# we probably should just have the benchmark be written *as cuda*
# and then invoke it with/without SCALE, like we do for every other
# test except this one.
export SCALE_ROOT="${CUDA_PATH}/../../"
