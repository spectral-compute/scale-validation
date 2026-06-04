#!/bin/bash
set -euo pipefail
OUT_DIR="$(realpath .)"
SRC_DIR="${SRC_DIR:-${OUT_DIR}/HeCBench}"

# Expect CUDAARCHS like 80, 86, 90 — not sm_80
CUDA_ARCH_NUM="${CUDAARCHS#sm_}"
BUILD_DIR="${SRC_DIR}/build/cuda-sm${CUDA_ARCH_NUM}"


# Create configure and build presets for available architectures that aren't already
# provided by HeCBench presets, and obviously the SCALE targets.
# Already given: hip-gfx90a, hip-gfx942
cat << EOF > $SRC_DIR/CMakeUserPresets.json
{
    "version": 3,

    "configurePresets": [
        {
            "name": "scale-cuda-sm$CUDA_ARCH_NUM",
            "displayName": "SCALE benchmark target",
            "inherits": "default",
            "cacheVariables": {
                "CMAKE_CUDA_COMPILER": "nvcc",
                "CMAKE_CUDA_ARCHITECTURES": "$CUDA_ARCH_NUM",
                "HECBENCH_ENABLE_CUDA": "ON",
                "HECBENCH_ENABLE_HIP": "OFF",
                "HECBENCH_ENABLE_SYCL": "OFF",
                "HECBENCH_ENABLE_OPENMP": "OFF",
                "HECBENCH_CUDA_ARCH": "$CUDA_ARCH_NUM"
            }
        },
        {
            "name": "hip-gfx1100",
            "displayName": "gfx1100",
            "inherits": "default",
            "cacheVariables": {
                "CMAKE_CUDA_COMPILER": "hipcc",
                "HECBENCH_ENABLE_CUDA": "OFF",
                "HECBENCH_ENABLE_HIP": "ON",
                "HECBENCH_ENABLE_SYCL": "OFF",
                "HECBENCH_ENABLE_OPENMP": "OFF",
                "HECBENCH_HIP_ARCH": "gfx1100"
            }
        },
        {
            "name": "hip-gfx1201",
            "displayName": "gfx1201",
            "inherits": "default",
            "cacheVariables": {
                "CMAKE_CUDA_COMPILER": "hipcc",
                "HECBENCH_ENABLE_CUDA": "OFF",
                "HECBENCH_ENABLE_HIP": "ON",
                "HECBENCH_ENABLE_SYCL": "OFF",
                "HECBENCH_ENABLE_OPENMP": "OFF",
                "HECBENCH_HIP_ARCH": "gfx1201"
            }
        }
    ],
    "buildPresets": [
        {
            "name": "scale-cuda-sm$CUDA_ARCH_NUM",
            "configurePreset": "scale-cuda-sm$CUDA_ARCH_NUM"
        },
        {
            "name": "hip-gfx1100",
            "configurePreset": "hip-gfx1100"
        },
        {
            "name": "hip-gfx1201",
            "configurePreset": "hip-gfx1201"
        }
    ]
}
EOF


(
    cd "$SRC_DIR"

    # Compilation Failures:

    # SCALE
    # (These will steadily be addressed.)
    # - gfx1201
    sed -i /prefetch/d src/CMakeLists.txt
    sed -i /blas-fp8gemm/d src/CMakeLists.txt
    # - sm_120
    sed -i /qkv/d src/CMakeLists.txt
    sed -i /d3q19-bgk/d src/CMakeLists.txt
    sed -i /permute/d src/CMakeLists.txt
    sed -i /quant3MatMul/d src/CMakeLists.txt
    sed -i /sobol/d src/CMakeLists.txt

    # We have also encountered the following compilation failures
    # with the following compilers
    # 
    # NVCC
    # - dp4a
    # - cm
    # - divergence
    # - ising
    # - mdh
    # - laplace
    # - logic-rewrite
    # 
    # HIP
    # - cm
    # - opticalFlow
    # - halo-finder
)
