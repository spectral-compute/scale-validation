#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

DEPS="$(realpath .)/deps"

dep() {
    local src="$1"
    shift
    cmake -B "build-$(basename "${src}")" -S "${src}" -GNinja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${DEPS}" -DCMAKE_PREFIX_PATH="${DEPS}" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5 "$@"
    cmake --build "build-$(basename "${src}")" --target install
}

dep libyaml -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF
dep yaml-cpp -DBUILD_SHARED_LIBS=ON -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF
dep fmt -DBUILD_SHARED_LIBS=ON -DFMT_TEST=OFF -DFMT_DOC=OFF
# Aerial's patch makes fmtlog use the fmt above, and adds the log levels nvlog uses.
if [[ ! -e fmtlog/.patched ]]; then
    git -C fmtlog apply --exclude=fmt --exclude=.gitmodules \
        "$(realpath aerial)/cuPHY-CP/container/patches/fmtlog.patch"
    touch fmtlog/.patched
fi
dep fmtlog
cp fmtlog/fmtlog.h fmtlog/fmtlog-inl.h "${DEPS}/include/"
dep CLI11 -DCLI11_BUILD_TESTS=OFF -DCLI11_BUILD_EXAMPLES=OFF -DCLI11_BUILD_DOCS=OFF
dep gsl-lite
dep wise_enum -DBUILD_TESTING=OFF
if [[ -d hdf5 ]]; then
    dep hdf5 -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DHDF5_BUILD_TOOLS=OFF -DHDF5_BUILD_EXAMPLES=OFF \
        -DHDF5_BUILD_HL_LIB=OFF -DHDF5_BUILD_CPP_LIB=OFF -DHDF5_BUILD_FORTRAN=OFF -DHDF5_ENABLE_Z_LIB_SUPPORT=OFF \
        -DHDF5_ENABLE_SZIP_SUPPORT=OFF
fi
# cuPHY requires TensorRT, for an optional ML channel estimator.
dep "${SCRIPT_DIR}/nvinfer-stub"

# cuPHY's CUDA code builds with -Werror all-warnings. These clang warnings, which nvcc doesn't have, fire on
# code guarded at run time (LDPC row loops), harmless style, or a real bug (polar_encoder.cu: `&& 0x1`).
if [[ -n "${SCALE_ENV:-}" ]]; then
    export NVCC_APPEND_FLAGS="${NVCC_APPEND_FLAGS} -Wno-array-bounds -Wno-parentheses-equality -Wno-constant-logical-operand"
fi

# cuPHY's own CMake project (the monorepo root also builds cuPHY-CP, which needs DPDK and DOCA).
# nvlog links libyaml and fmtlog by bare name, hence the -L. RPATH rather than RUNPATH, which doesn't
# apply to the deps' own dependencies (libfmt for libfmtlog). fmtlog.h and NvInfer.h have no CMake
# package, hence the standard include directory.
args=(
    -DCMAKE_TOOLCHAIN_FILE="$(realpath aerial/cuPHY/cmake/toolchains/native)"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER=nvcc
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_PREFIX_PATH="${DEPS};$(realpath mathdx/nvidia/mathdx/*)"
    -DCMAKE_EXE_LINKER_FLAGS="-L${DEPS}/lib -Wl,-rpath,${DEPS}/lib -Wl,--disable-new-dtags"
    -DCMAKE_SHARED_LINKER_FLAGS="-L${DEPS}/lib -Wl,-rpath,${DEPS}/lib -Wl,--disable-new-dtags"
    -DCMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES="${DEPS}/include"
    -DCMAKE_CUDA_STANDARD_INCLUDE_DIRECTORIES="${DEPS}/include"
    -DNVINFER="${DEPS}/lib/libnvinfer.so"
    -DENABLE_TESTS=ON
    -DBUILD_DOCS=OFF
    -GNinja
)
cmake "${args[@]}" -B build -S aerial/cuPHY

# -k 0: build as much as possible, for more signal on what's unsupported.
ninja -C build -k 0
