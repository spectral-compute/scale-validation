#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# sgl-kernel: SGLang's library of ahead-of-time compiled CUDA kernels.
source "${SCALE_VALIDATION}/pytorch/util/build-env.sh"
source .venv/bin/activate

# FA3 is Hopper-only. nvcc's --threads only parallelises across gencodes, of
# which there's now one, so leave the parallelism to the build tool.
export CMAKE_ARGS="${CMAKE_ARGS} -DSGL_KERNEL_ENABLE_FA3=OFF -DSGL_KERNEL_COMPILE_THREADS=1"
export CMAKE_BUILD_PARALLEL_LEVEL="${MAX_JOBS}"

python -m pip install "scikit-build-core>=0.10" "cmake>=3.26" ninja wheel
python -m pip install --no-build-isolation --no-deps -v ./sglang/python/sglang/kernels/aot
