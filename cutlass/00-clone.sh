#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/cutlass"
cd "${OUT_DIR}/cutlass"

do_clone cutlass https://github.com/NVIDIA/cutlass.git "$(get_version cutlass)"

# Disable incredibly obnoxious warning spam the only way we can.
sed -Ee 's|-Xcompiler=-Wconversion||g' -i"" "${OUT_DIR}/cutlass/cutlass/CMakeLists.txt"
