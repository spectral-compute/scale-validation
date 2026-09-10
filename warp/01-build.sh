#!/bin/bash

set -ETeuo pipefail

cd warp

# build_lib.py imports warp.build_dll / warp.context, which import numpy at
# module load time, so numpy has to be importable before it even starts. Use
# a venv rather than relying on whatever the environment happens to have.
python3 -m venv venv
source venv/bin/activate
pip install numpy

# --use-dynamic-cuda makes warp dlopen libcuda.so at runtime instead of
# linking against a real NVIDIA CUDA toolkit at build time -- this is what
# lets it pick up SCALE's libcuda.so/libnvrtc.so instead.
#
# --no-use-libmathdx: libmathdx (cuBLASDx/cuFFTDx/cuSOLVERDx tile ops) is an
# optional NVIDIA-only extra fetched as a prebuilt binary blob via packman;
# it has no SCALE/AMD equivalent and isn't needed for the core runtime this
# test exercises, so skip it rather than depending on that fetch succeeding.
python3 build_lib.py --use-dynamic-cuda --no-use-libmathdx
