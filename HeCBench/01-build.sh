#!/usr/bin/env bash
set -euo pipefail
OUT_DIR="$(realpath .)"
SRC_DIR="${OUT_DIR}/HeCBench"

# Expect CUDAARCHS like 80, 86, 90 — not sm_80
CUDA_ARCH_NUM="${CUDAARCHS#sm_}"
BUILD_DIR="${SRC_DIR}/build/cuda-sm${CUDA_ARCH_NUM}"


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
        }
    ],
    "buildPresets": [
        {
            "name": "scale-cuda-sm$CUDA_ARCH_NUM",
            "inherits": "default",
            "configurePreset": "scale-cuda-sm$CUDA_ARCH_NUM"
        }
    ]
}
EOF

python3 $SRC_DIR/tools/hecbench build --preset scale-cuda-sm${CUDA_ARCH_NUM}

# cmake -S "${SRC_DIR}" -B "${BUILD_DIR}" -G Ninja \
#     -DCMAKE_CUDA_COMPILER=nvcc \
#     -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH_NUM}" \
#     -DHECBENCH_CUDA_ARCH="${CUDA_ARCH_NUM}" \
#     -DHECBENCH_ENABLE_HIP=OFF \
#     -DHECBENCH_ENABLE_SYCL=OFF \
#     -DHECBENCH_ENABLE_OPENMP=OFF

# # If you need to continue even if some targets fail add to ninja "|| true"
# ninja -C "${BUILD_DIR}" -k 0

# python3 $SRC_DIR/tools/generate_metadata.py -o $BUILD_DIR/benchmark_input_config.yaml
