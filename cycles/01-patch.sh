#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Fix a misuse of `ifndef(HIP)` that breaks CUDA
patch -p0 -d "cycles" <"${SCRIPT_DIR}/intrinsics.patch"
