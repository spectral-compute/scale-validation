#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

cd TCLB
./tools/install.sh rdep
make configure
./configure --with-cuda-arch="${CUDAARCHS}"
make d2q9 -j"$(nproc)"
