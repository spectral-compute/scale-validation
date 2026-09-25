#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# colmap wants to spit some stuff out to our home directory
export HOME="$PWD"

ctest --output-on-failure "-j$(nproc)"
