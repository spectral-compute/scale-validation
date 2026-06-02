#!/bin/bash
set -ETeuo pipefail
shopt -s nullglob

cd pytorch

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi

source .venv/bin/activate
python -m pip install --upgrade pip wheel
python -m pip install "setuptools==81.0.0"
python -m pip install pyyaml typing_extensions jinja2 numpy

cd "build/pytorch"

torch-arch() {
  if ((${#CUDAARCHS} == 2)); then
    echo "${CUDAARCHS:0:1}.${CUDAARCHS:1:1}"
  else
    echo "${CUDAARCHS:0:2}.${CUDAARCHS:2:1}"
  fi
}

export CFLAGS="\
    -march=native \
    -mtune=native \
    -Wno-inconsistent-missing-destructor-override \
    -Wno-deprecated-copy-with-user-provided-dtor \
    -Wno-dangling-reference \
    -Wno-redundant-move
"

export CXXFLAGS="${CFLAGS}"
export CUDNN_INCLUDE_DIR=/usr/include
export CUDNN_LIB_DIR=/usr/lib
export TORCH_CUDA_ARCH_LIST=$(torch-arch)
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
export TORCH_USE_CUDA_DSA=OFF

# clang >= 18 use c++20 mangling, but PyTorch expects c++17 mangling
if [[ "$(nvcc --version)" == *" SCALE "* ]]; then
  export CUDAFLAGS="-fclang-abi-compat=17 -Xcuda-ptxas -v"
fi

export CMAKE_ARGS="-DBUILD_BINARY=OFF -DBUILD_TEST=OFF"

python setup.py build
python setup.py install --root=$PWD/../../install --skip-build
