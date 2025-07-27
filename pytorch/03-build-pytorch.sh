#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

cd "${OUT_DIR}/pytorch/build"


#############
# CONFIGURE #
#############

export CC="${CUDA_PATH}/bin/gcc"
export CXX="${CUDA_PATH}/bin/g++"
export CFLAGS="\
    -march=native \
    -mtune=native \
    -Wno-inconsistent-missing-destructor-override \
    -Wno-deprecated-copy-with-user-provided-dtor \
    -Wno-dangling-reference \
    -Wno-redundant-move
"
export _GLIBCXX_USE_CXX11_ABI=TRUE

export CUDAHOSTCXX="${CUDA_PATH}/bin/g++"

export CUDNN_INCLUDE_DIR=/usr/include
export CUDNN_LIB_DIR=/usr/lib
export USE_SYSTEM_NCCL=ON

# Wat.
export CUDAARCHS="86"
export TORCH_CUDA_ARCH_LIST="8.6"

export USE_CUDA=ON
export USE_CUDNN=OFF
export CAFFE2_USE_CUDNN=OFF

export USE_NCCL=OFF
export USE_DISTRIBUTED=OFF
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
export USE_NUMPY=OFF
export USE_OPENCV=OFF
export USE_ROCM=OFF

export BUILD_CAFFE2=ON
export BUILD_CAFFE2_OPS=ON

export BUILD_BINARY=ON
export BUILD_TEST=ON

export MAX_JOBS="${BUILD_JOBS}"
export VERBOSE="${VERBOSE}"


#########
# BUILD #
#########

# Build PyTorch
python3 setup.py build


###########
# INSTALL #
###########

# Install PyTorch Python
INSTALL_DIR="$(pwd)"/../install/
python3 setup.py install --root="${INSTALL_DIR}" --optimize=1 --skip-build

# Link the C++ API to a sensible place (useful for testing).
function symlinkAllIn
{
    _DST="$1"
    _SRC="$2"

    mkdir -p "${_DST}"
    for F in "${_SRC}"/* ; do
        B="$(basename "${F}")"
        ln -s "${F}" "${_DST}/${B}"
    done
}

PYVER=$(python3 --version | sed -E 's/Python ([0-9]+\.[0-9]+)\.[0-9]+/\1/')
SRC="${INSTALL_DIR}/usr/lib/python${PYVER}/site-packages/torch"
DST="${INSTALL_DIR}/usr"

symlinkAllIn "${DST}/lib" "${SRC}/lib"
for D in "${SRC}/include/"* "${SRC}/include/torch/csrc/api/include/"* ; do
    symlinkAllIn "${DST}/include/$(basename ${D})" "${D}"
done
