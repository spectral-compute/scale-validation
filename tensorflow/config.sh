# Turn various things on and off.
export TF_ENABLE_XLA=1
export TF_IGNORE_MAX_BAZEL_VERSION=1
export TF_NCCL_VERSION=""
export TF_NEED_MPI=0
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_ROCM=0
export TF_NEED_TENSORRT=0
export TF_SET_ANDROID_WORKSPACE=0

# Bazel arguments to turn things on and off.
BAZEL_CONFIG= # For example: "--config=noaws"

# Compiler.
export GCC_HOST_COMPILER_PATH="$(realpath "${CUDA_PATH}/bin/gcc")"
export HOST_C_COMPILER="$(realpath "${CUDA_PATH}/bin/gcc")"
export HOST_CXX_COMPILER="$(realpath "${CUDA_PATH}/bin/g++")"
export CC_OPT_FLAGS="-march=native -mtune=native"
export TF_CUDA_CLANG=0
export TF_DOWNLOAD_CLANG=0

# Python
export PYTHON_BIN_PATH=/usr/bin/python3
export USE_DEFAULT_PYTHON_LIB_PATH=1

# CUDA.
export TF_NEED_CUDA=1
export CUDA_TOOLKIT_PATH="${CUDA_PATH}"
export CUDNN_INSTALL_PATH="${CUDA_PATH}"
export TF_CUDA_PATHS="${CUDA_PATH}"
export TF_CUDA_VERSION=$("${CUDA_PATH}/bin/nvcc" --version | sed -n 's/^.*release \(.*\),.*/\1/p')
export TF_CUDA_COMPUTE_CAPABILITIES=$(echo $GPU_ARCH | sed -E 's/sm_([0-9]+)([0-9])/\1.\2/')

# Other things that apparently can't be autodetected.
export TMP=/tmp
