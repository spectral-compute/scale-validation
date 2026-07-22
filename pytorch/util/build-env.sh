# Create the build environments for torch and vision

# Build the TORCH_CUDA_ARCH_LIST; <major>.<minor>
torch-arch() {
  if ((${#CUDAARCHS} == 2)); then
    echo "${CUDAARCHS:0:1}.${CUDAARCHS:1:1}"
  else
    echo "${CUDAARCHS:0:2}.${CUDAARCHS:2:1}"
  fi
}
export TORCH_CUDA_ARCH_LIST=$(torch-arch)

export CFLAGS="\
    -Wno-inconsistent-missing-destructor-override \
    -Wno-deprecated-copy-with-user-provided-dtor \
    -Wno-dangling-reference \
    -Wno-redundant-move
"

# TODO(#1156): See if these can/should be pared down further: env vars which have no effect are noise in the script.
export CXXFLAGS="${CFLAGS}"
export CUDNN_INCLUDE_DIR=/usr/include
export CUDNN_LIB_DIR=/usr/lib
export USE_CUDA=ON
export USE_CUDNN=OFF
export USE_CUFILE=OFF
export CAFFE2_USE_CUDNN=OFF
export USE_CUSPARSELT=OFF
export USE_NCCL=OFF
export USE_DISTRIBUTED=ON
export USE_FAKELOWP=OFF
export USE_FBGEMM=OFF
export USE_FFMPEG=OFF
export USE_GFLAGS=OFF
export USE_GLOG=OFF
export USE_ITT=OFF
export USE_KINETO=OFF
export USE_LEVELDB=OFF
export USE_LMDB=OFF
export USE_MKLDNN=OFF
export USE_NUMPY=ON
export USE_OPENCV=OFF
export USE_ROCM=OFF
export BUILD_CAFFE2=ON
export BUILD_CAFFE2_OPS=ON
export BUILD_BINARY=OFF
export BUILD_TEST=OFF
export CMAKE_POLICY_VERSION_MINIMUM=3.5
export FORCE_CUDA=1
export MAX_JOBS=$(nproc)

# PyTorch has its own env var to set the CUDA compiler
export PYTORCH_NVCC=${CUDACXX}

# --generate-dependencies-with-compile is not a valid clang option
export TORCH_EXTENSION_SKIP_NVCC_GEN_DEPENDENCIES=1

# clang >= 18 use c++20 mangling, but PyTorch expects c++17 mangling
if [[ "$(nvcc --version)" == *" SCALE "* ]]; then
  # This has to CMAKE_CUDA_FLAGS, not CUDAFLAGS (TODO: maybe we want to go around setup.py and call
  # cmake directly? The pytorch build instructions are pretty sparse)
  export CMAKE_CUDA_FLAGS="-fclang-abi-compat=17"
fi

export CMAKE_ARGS="-DBUILD_BINARY=OFF -DBUILD_TEST=OFF"
