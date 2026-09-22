#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER="clang"
    -DCMAKE_CXX_COMPILER="clang++"

    -DSTRINGZILLA_BUILD_TEST=1
)
cmake \
    "${args[@]}" \
    -B"build" \
    "StringZilla"

make -O -C "build" -j"$(nproc)"
