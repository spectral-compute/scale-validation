#!/bin/bash

set -ETeuo pipefail

cd TCLB
./tools/install.sh rdep
make configure
./configure --with-cuda-arch="${SCALE_FAKE_CUDA_ARCH}"
make d2q9 -j$(nproc)
