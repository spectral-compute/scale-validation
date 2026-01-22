#!/bin/bash

set -ETeuo pipefail

TCLB/tools/install.sh rdep
make -C TCLB configure
./TCLB/configure --with-cuda-arch="${SCALE_FAKE_CUDA_ARCH}"
make -C TCLB d2q9 -j$(nproc)
