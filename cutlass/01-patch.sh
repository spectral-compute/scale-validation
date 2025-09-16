#!/bin/bash


set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

SRCDIR="${OUT_DIR}/cutlass/cutlass"

# This could be done better, device properties doesn't have a clock rate any more
sed -i 's$deviceProperties.clockRate$2300$g' "$SRCDIR"/test/unit/common/filter_architecture.cpp
sed -i 's$properties\[0\].clockRate$2300$g' "$SRCDIR"/tools/profiler/src/options.cu
sed -i 's$prop.clockRate$2300$g' "$SRCDIR"/tools/profiler/src/options.cu
