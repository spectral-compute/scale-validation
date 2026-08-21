#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone cutlass https://github.com/NVIDIA/cutlass.git "$(get_version cutlass)"

# Disable incredibly obnoxious warning spam the only way we can.
sed -Ee 's|-Xcompiler=-Wconversion||g' -i"" "cutlass/CMakeLists.txt"
