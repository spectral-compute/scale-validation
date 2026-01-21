#!/bin/bash

set -ETeuo pipefail

TCLB/tools/install.sh rdep
make -C TCLB configure
./TCLB/configure --with-cuda-arch="$(echo "${GPU_ARCH}" | sed -E 's/^sm_//')"
make -C TCLB d2q9 -j$(nproc)
