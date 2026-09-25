#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd TCLB
./tools/install.sh rdep
make configure
./configure --with-cuda-arch="${CUDAARCHS}"
make d2q9 -j"$(nproc)"
