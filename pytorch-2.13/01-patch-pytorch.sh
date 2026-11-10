#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The pytorch project's patches, then what 2.13 needs on top.
"${SCALE_VALIDATION}/pytorch/01-patch-pytorch.sh"

OUT_DIR=$(realpath .)

# Some ROCm-only device code is chosen by the GPU architecture macros alone, which SCALE defines too (it really is
# compiling for that GPU). That code uses HIP builtins and 64-lane masks, so also require a ROCm build.
cd "${OUT_DIR}/pytorch/aten/src/ATen/native/cuda"
for F in KernelUtils.cuh ScatterGatherKernel.cu Indexing.cu int4mm.cu; do
    sed -Ee '/USE_ROCM/!s/^#if (\(?defined ?\(__gfx[^\\]*)$/#if defined(USE_ROCM) \&\& (\1)/' -i "${F}"
    if grep -E '^#if [^\\]*defined ?\(__gfx[^\\]*$' "${F}" | grep -qv USE_ROCM; then
        log "${F}: a __gfx condition without USE_ROCM is left"
        exit 1
    fi
done

# PyTorch 2.13 builds CUDA graph conditional nodes (CUDA 12.4's cudaGraphConditionalHandle) unless on ROCm. SCALE
# has no conditional nodes, so take the ROCm route there: the feature then reports itself unsupported.
cd "${OUT_DIR}/pytorch"
for F in aten/src/ATen/cuda/CUDAGraph.h aten/src/ATen/cuda/CUDAGraph.cpp aten/src/ATen/cuda/CUDAGraph.cu; do
    if [[ ! -f "${F}" ]] || ! grep -q 'CUDA_VERSION >= 12040' "${F}"; then
        continue
    fi
    sed -Ee '/CUDA_VERSION >= 12040/s/defined\(USE_ROCM\)/(defined(USE_ROCM) || defined(__REDSCALE__))/' -i "${F}"
    if grep 'CUDA_VERSION >= 12040' "${F}" | grep -v '__REDSCALE__' | grep -q USE_ROCM; then
        log "${F}: a CUDA_VERSION >= 12040 condition without __REDSCALE__ is left"
        exit 1
    fi
done
