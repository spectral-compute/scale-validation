#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

OUT_DIR="$(realpath .)"
cd sglang/python/sglang/kernels/aot
mv pyproject_rocm.toml pyproject.toml

# Upstream's ROCm images use torch 2.9-2.11; torch 2.14's headers need C++20.
sed -e 's|"-std=c++17",|"-std=c++20",|' -i setup_rocm.py
grep -qF '"-std=c++20",' setup_rocm.py

case "${TEST_GPU_ARCH}" in
gfx942 | gfx950 | gfx1250)
    # Upstream's ROCm targets.
    ;;
gfx11* | gfx12*)
    # Upstream's patch for gfx1151 (Strix Halo) applies to any wave32 RDNA part:
    # it lifts setup_rocm.py's arch allowlist and fixes WARP_SIZE to 32.
    sed -e "s|gfx1151|${TEST_GPU_ARCH}|g" \
        "${OUT_DIR}/sglang/docker/patches/sgl-kernel-gfx1151.sh" >patch-rdna.sh
    sh patch-rdna.sh setup_rocm.py
    ;;
*)
    log "SGLang's ROCm build doesn't support ${TEST_GPU_ARCH}"
    exit 1
    ;;
esac
