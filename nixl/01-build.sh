#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Build UCX from source. NIXL requires UCX with --enable-mt (multi-thread
# support). Ubuntu's packaged UCX is too old (1.16) and lacks the API NIXL
# uses. We build UCX 1.21.x (NIXL's tested version) against the CUDA toolkit
mkdir -p ucx-install
ucx_install_dir="$(realpath ucx-install)"
(
    cd ucx
    ./autogen.sh
    ./configure \
        --prefix="${ucx_install_dir}" \
        --with-cuda="${CUDA_DIR}" \
        --enable-mt
    make -O -j"$(nproc)"
    make install
)

# Make the freshly-built UCX visible to the NIXL build.
export PKG_CONFIG_PATH="${ucx_install_dir}/lib/pkgconfig:${PKG_CONFIG_PATH-}"
export LD_LIBRARY_PATH="${ucx_install_dir}/lib:${LD_LIBRARY_PATH-}"

# The GDS plugin needs NVIDIA's cuFile, which only NVIDIA's toolkit provides.
args=(-Dbuild_tests=false)
if [ ! -e /usr/local/cuda/include/cufile.h ]; then
    args+=(-Dgds_path=)
fi

# Configure NIXL. Meson will discover  UCX from PKG_CONFIG_PATH above. build_tests is disabled
# explicitly: NIXL's gtest suite did not build cleanly with the default and
# 02-example.sh only runs the bundled example.
# Wipe build/ first because `meson setup` fails on a pre-existing one.
(
    cd nixl
    rm -rf build
    meson setup build "${args[@]}"
    ninja -C build
)
