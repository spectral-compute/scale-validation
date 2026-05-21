#!/bin/bash
#
# Build UCX from source, then build NIXL against it. Run after 00-clone.sh
# from the same working directory.

set -ETeuo pipefail

# Build UCX from source. NIXL requires UCX with --enable-mt (multi-thread
# support). Ubuntu's packaged UCX is too old (1.16) and lacks the API NIXL
# uses. We build UCX 1.21.x (NIXL's tested version) against the CUDA toolkit
# made available via test.sh's environment setup.
mkdir -p ucx-install
ucx_install_dir="$(realpath ucx-install)"
(
  cd ucx
  ./autogen.sh
  ./configure \
    --prefix="${ucx_install_dir}" \
    --with-cuda="${CUDA_DIR}" \
    --enable-mt
  make -j"$(nproc)"
  make install
)

# Make the freshly-built UCX visible to the NIXL build.
export PKG_CONFIG_PATH="${ucx_install_dir}/lib/pkgconfig:${PKG_CONFIG_PATH-}"
export LD_LIBRARY_PATH="${ucx_install_dir}/lib:${LD_LIBRARY_PATH-}"

# Configure NIXL. Meson will discover CUDA from the environment variables
# test.sh set, and UCX from PKG_CONFIG_PATH above. build_tests is disabled
# explicitly: NIXL's gtest suite did not build cleanly with the default and
# 02-example.sh only runs the bundled example. Revisit if/when tests build.
# Wipe build/ first because `meson setup` fails on a pre-existing one.
(
  cd nixl
  rm -rf build
  meson setup build -Dbuild_tests=false
  ninja -C build
)
