#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

# We have to copy so the late stages of setup.py build work.
rm -rf "${OUT_DIR}/pytorch/build"
cp -r --reflink=auto "${OUT_DIR}/pytorch/pytorch" "${OUT_DIR}/pytorch/build"
cd "${OUT_DIR}/pytorch/build"

# Configure.
export CC="${CUDA_PATH}/bin/gcc"
export CXX="${CUDA_PATH}/bin/g++"
export CFLAGS="-march=native -mtune=native"
export _GLIBCXX_USE_CXX11_ABI=TRUE

export CUDAHOSTCXX="${CUDA_PATH}/bin/g++"
export CUDNN_INCLUDE_DIR=/usr/include
export CUDNN_LIB_DIR=/usr/lib
export USE_SYSTEM_NCCL=ON
export TORCH_CUDA_ARCH_LIST="$(echo $GPU_ARCH | sed -E 's/sm_([0-9]+)([0-9])/\1.\2/')"

export BUILD_BINARY=ON
export BUILD_CAFFE2_OPS=ON
export USE_CUDA=ON
export USE_CUDNN=ON
export USE_DISTRIBUTED=OFF
export USE_FFMPEG=OFF
export USE_GFLAGS=ON
export USE_GLOG=ON
export USE_LEVELDB=ON
export USE_LMDB=ON
export USE_MKLDNN=OFF
export USE_NUMPY=ON
export USE_OPENCV=OFF
export USE_ROCM=OFF

export BUILD_BINARY=ON
export BUILD_TEST=ON

export MAX_JOBS="$(nproc)"
export VERBOSE="${VERBOSE}"

# Patch PyTorch.
sed -E 's|target_include_directories[(][$][{]test_name[}] PRIVATE [$]<INSTALL_INTERFACE:include>[)]|\0\ntarget_include_directories(${test_name} PRIVATE $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/include>)|' -i caffe2/CMakeLists.txt
sed -E 's/%laneid/%%laneid/g' -i aten/src/THC/THCAsmUtils.cuh
sed -E 's/%laneid/%%laneid/g' -i caffe2/utils/GpuDefs.cuh
sed -E 's/\(ZERO_MACRO/((T)ZERO_MACRO/' -i aten/src/THCUNN/LogSigmoid.cu
sed -E 's/(#define [A-Za-z0-9_]+[(].*) va_printf/\1 ::printf/' -i third_party/cub/cub/util_debug.cuh
sed -E 's/double sigma_gn = 0.0;/double sigma_gn = 0.0; (void) sigma_gn;/' -i third_party/benchmark/src/complexity.cc
sed -E 's/options(_clone)?[.]continue_through_error/True/' ../pytorch/test/run_test.py > test/run_test.py

for F in third_party/fbgemm/include/fbgemm/FbgemmI8Spmdm.h \
         third_party/fbgemm/src/FbgemmFP16.cc \
         third_party/fbgemm/src/FbgemmConv.cc \
         third_party/fbgemm/src/FbgemmI8DepthwisePerChannelQuantAvx2.cc \
         third_party/fbgemm/src/FbgemmI8Depthwise3DAvx2.cc \
         third_party/fbgemm/src/FbgemmI8DepthwiseAvx2.cc \
         third_party/fbgemm/src/Fbgemm.cc \
         third_party/fbgemm/src/QuantUtilsAvx2.cc \
         third_party/fbgemm/src/RefImplementations.cc \
         third_party/fbgemm/src/QuantUtils.cc \
         third_party/fbgemm/src/PackWeightsForConv.cc \
         third_party/fbgemm/include/fbgemm/ConvUtils.h ; do
    TEXT="$(cat "$F")"
    echo '#include <stdexcept>' > "$F"
    echo "$TEXT" >> "$F"
done

for F in third_party/fbgemm/include/fbgemm/Utils.h \
         third_party/fbgemm/include/fbgemm/UtilsAvx2.h ; do
    TEXT="$(cat "$F")"
    echo '#include <cstdint>' > "$F"
    echo "$TEXT" >> "$F"
done

for F in third_party/benchmark/src/benchmark_register.h ; do
    TEXT="$(cat "$F")"
    echo '#include <limits>' > "$F"
    echo "$TEXT" >> "$F"
done

for F in third_party/fbgemm/src/FbgemmFP16UKernelsAvx2.cc \
         third_party/fbgemm/src/FbgemmFP16UKernelsAvx512.cc \
         third_party/fbgemm/src/FbgemmFP16UKernelsAvx512_256.cc ; do
    TEXT="$(cat "$F")"
    echo '#undef __clang__' > "$F"
    echo "$TEXT" >> "$F"
done

for F in third_party/fbgemm/include/fbgemm/Types.h ; do
    TEXT="$(cat "$F")"
    echo '#if !defined(__extern_always_inline)' > "$F"
    echo '#  define __extern_always_inline extern __inline__ __attribute__((always_inline))' >> "$F"
    echo '#endif' >> "$F"
    echo "$TEXT" >> "$F"
done

# Build PyTorch
python3 setup.py build

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
