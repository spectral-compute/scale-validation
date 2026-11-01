#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Native ROCm baseline. FAISS hipifies its GPU code itself.
cmake -B faiss-build -S faiss \
    -DFAISS_ENABLE_GPU=ON \
    -DFAISS_ENABLE_ROCM=ON \
    -DFAISS_ENABLE_PYTHON=OFF \
    -DBUILD_TESTING=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_HIP_ARCHITECTURES="${TEST_GPU_ARCH}" \
    -DCMAKE_INSTALL_PREFIX="${PWD}/faiss-install"
cmake --build faiss-build --target install -j"$(nproc)"

# tsne-cuda has no HIP backend: hipify it, and build what its CMakeLists.txt would (libtsnecuda.so
# in a copy of the Python package) with the same flags, plus -munsafe-fp-atomics: CUDA's float
# atomicAdd is a hardware atomic, but HIP's is otherwise a CAS loop (40x slower in
# compute_interpolated_indices). hipFFT has no CUFFT_LICENSE_ERROR.
sed -i '/case CUFFT_LICENSE_ERROR:/,+1d' tsne-cuda/src/util/cuda_utils.cu
find tsne-cuda/src \( -name '*.cu' -o -name '*.h' \) -exec hipify-perl -inplace -quiet-warnings {} +
find tsne-cuda/src \( -name '*.cu' -o -name '*.h' \) -exec sed -i \
    -e 's@#include <hipblas.h>@#include <hipblas/hipblas.h>@' \
    -e 's@#include <hipsparse.h>@#include <hipsparse/hipsparse.h>@' \
    -e 's@#include <hipfft.h>@#include <hipfft/hipfft.h>@' \
    -e 's@#include <hipsolver.h>@#include <hipsolver/hipsolver.h>@' {} +

mkdir -p build/obj
cp -r tsne-cuda/src/python build/python
SOURCES=(
    util/data_utils.cu util/debug_utils.cu util/cuda_utils.cu util/thrust_utils.cu
    util/distance_utils.cu util/math_utils.cu util/matrix_broadcast_utils.cu util/random_utils.cu
    util/reduce_utils.cu kernels/apply_forces.cu kernels/attr_forces.cu kernels/rep_forces.cu
    kernels/perplexity_search.cu kernels/nbodyfft.cu ext/pymodule_ext.cu fit_tsne.cu
)
for S in "${SOURCES[@]}"; do
    echo "hipcc -x hip -c --offload-arch=${TEST_GPU_ARCH} -O3 -std=c++17 -munsafe-fp-atomics -Wno-register -fPIC -fopenmp -DNDEBUG \
        -DNO_ZMQ -DFINTEGER=int -DUSE_AMD_ROCM -Itsne-cuda/src -Itsne-cuda/src/include \
        -Itsne-cuda/third_party -Ifaiss-install/include tsne-cuda/src/${S} \
        -o build/obj/${S//\//_}.o"
done | xargs -P "$(nproc)" -I{} sh -c '{}'
hipcc -shared -fopenmp -o build/python/tsnecuda/libtsnecuda.so build/obj/*.o \
    -Lfaiss-install/lib -Wl,-rpath,"${PWD}/faiss-install/lib" -lfaiss \
    -lhipblas -lhipfft -lhipsparse
