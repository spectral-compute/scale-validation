#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

source .venv/bin/activate

# torch.utils.cpp_extension hipifies the extension. Upstream's setup.py passes nvcc-only flags
# and asks the GPU for an sm_ architecture; PYTORCH_ROCM_ARCH picks the target instead.
sed -Ee 's|^arch_flags, detected_arch = get_cuda_arch_flags\(\)$|arch_flags, detected_arch = [], "rocm"|' \
    -e '/^nvcc_args \+= \["-lineinfo"/d' \
    -e 's|"--use_fast_math",|"-ffast-math",|' \
    -i ppisp/setup.py
grep -q '"-ffast-math"' ppisp/setup.py
if grep -q 'lineinfo' ppisp/setup.py; then exit 1; fi

# HIP wants a 64-bit mask. The 32-lane reduction is still right on wave64: lane 0 and lane 32
# each sum their half, and the kernels use them as two warps.
sed -Ee 's|__shfl_down_sync\(0xffffffffu, v, offset\)|__shfl_down(v, offset)|' \
    -i ppisp/ppisp/src/ppisp_impl.cu
if grep -q '_sync(' ppisp/ppisp/src/ppisp_impl.cu; then exit 1; fi

export PYTORCH_ROCM_ARCH="${TEST_GPU_ARCH}"
python -m pip install -v --no-build-isolation ./ppisp numpy matplotlib
