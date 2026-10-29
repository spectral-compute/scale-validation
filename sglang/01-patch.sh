#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source "${SCALE_VALIDATION}/pytorch/util/cutlass-patches.sh"
patch_pytorch_cutlass pytorch/third_party/cutlass

# Work around SCALE bugs that break the build; each patch says which.
for patch in "${SCRIPT_DIR}"/patches/torch/*.patch; do
    git -C pytorch apply "${patch}"
done
for patch in "${SCRIPT_DIR}"/patches/sglang/*.patch; do
    git -C sglang apply "${patch}"
done

cd sglang/python/sglang/kernels/aot

# sgl-kernel downloads its own CUTLASS at configure time, which needs the same
# patches as torch's. Fetch the one it pins (and check its hash) now, for
# 04-build-sgl-kernel.sh to point FetchContent at.
url="$(grep -A1 'repo-cutlass$' CMakeLists.txt | grep -oE 'NVIDIA/cutlass/archive/[0-9a-f]+\.tar\.gz')"
sha="$(grep -A2 'repo-cutlass$' CMakeLists.txt | grep -oE 'SHA256=[0-9a-f]+' | cut -d = -f 2)"
mkdir "${OLDPWD}/sgl-kernel-cutlass"
curl -fsSL "https://github.com/${url}" -o cutlass.tar.gz
echo "${sha}  cutlass.tar.gz" | sha256sum -c
tar -xzf cutlass.tar.gz -C "${OLDPWD}/sgl-kernel-cutlass" --strip-components 1
rm cutlass.tar.gz
patch_pytorch_cutlass "${OLDPWD}/sgl-kernel-cutlass"

# sgl-kernel hardcodes gencodes from sm_80 up to sm_121a. SCALE maps every
# compute capability to the one target GPU, so these would build the Hopper and
# Blackwell code paths for it. Drop them: CMake then builds for ${CUDAARCHS},
# which it reads from the environment.
sed -Ee 's|"-gencode=arch=compute_[0-9]+[af]?,code=sm_[0-9]+[af]?"||' \
    -i CMakeLists.txt cmake/flashmla.cmake
! grep -q -- '-gencode=' CMakeLists.txt cmake/flashmla.cmake
