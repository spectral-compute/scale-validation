#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

# colmap wants to spit some stuff out to our home directory
export HOME="$PWD"

ctest --output-on-failure "-j$(nproc)"
