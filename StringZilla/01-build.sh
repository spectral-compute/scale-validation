#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="clang" \
    -DCMAKE_CXX_COMPILER="clang++" \
    -DSTRINGZILLA_BUILD_TEST=1 \
    -B"build" \
    "StringZilla"

make -C "build" -j"$(nproc)"
