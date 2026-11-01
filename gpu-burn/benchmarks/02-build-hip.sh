#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# gpu-burn has no HIP backend: hipify it, after replacing the pre-CUDA-4.0 launch API
# (cuParamSet*, cuFuncSetBlockShape, cuLaunchGridAsync), which HIP lacks, with cuLaunchKernel.
cd gpu-burn
git apply "${SCRIPT_DIR}/hip-port.patch"
"${ROCM_PATH}/bin/hipify-perl" -inplace gpu_burn-drv.cpp compare.cu

hipcc -O3 -Wno-unused-result -Wno-deprecated-declarations -std=c++11 -DIS_JETSON=false -I"${ROCM_PATH}/include/hipblas" -c gpu_burn-drv.cpp -o gpu_burn-drv.o
hipcc -o gpu_burn gpu_burn-drv.o -O3 -lhipblas
hipcc --genco --offload-arch="${TEST_GPU_ARCH}" -O3 compare.cu -o compare.fatbin
