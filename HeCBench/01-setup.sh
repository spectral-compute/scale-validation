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

# Remove benchmarks that don't compile or build for a given architecture
(
    cd "$SRC_DIR"

    # Compilation Failures:
    # SCALE; gfx1201
    sed -i /gels/d src/CMakeLists.txt
    sed -i /prefetch/d src/CMakeLists.txt
    sed -i /streamOrderedAllocation/d src/CMakeLists.txt
    sed -i /blas-fp8gemm/d src/CMakeLists.txt

    # Nvidia
    sed -i /dp4a/d src/CMakeLists.txt

    # HIP; gfx90a
    sed -i /nms/d src/CMakeLists.txt
    
    # HIP; gfx942
    sed -i /opticalFlow/d src/CMakeLists.txt

    # HIP
    # TODO: Work around `dims-local.c` being a Makefile target not included in the CMake process
    # You need to either `make` manually, or call that target separately, it's not part of the
    # CMake build process they're trying to move to (yet).
    sed -i /halo-finder/d src/CMakeLists.txt

    # SCALE; gfx1201
    # Nvidia
    sed -i /cm/d src/CMakeLists.txt
    sed -i /divergence/d src/CMakeLists.txt
    sed -i /ising/d src/CMakeLists.txt
    sed -i /mdh/d src/CMakeLists.txt
    sed -i /laplace/d src/CMakeLists.txt
    sed -i /logic-rewrite/d src/CMakeLists.txt

    # SCALE
    # Small linking issue, being addressed as we speak
    sed -i /determinant/d src/CMakeLists.txt
)
