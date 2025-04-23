#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# We need the patched version for now (empty kernel, #483;#506)
patch -p0 -d "${OUT_DIR}/AMGX/AMGX/thrust/dependencies/cub" < "${SCRIPT_DIR}/device_util.patch"

# Patch an integer overflow in the Memory_Use_* tests
patch -p0 -d "${OUT_DIR}/AMGX/AMGX" < "${SCRIPT_DIR}/memory_use_int_overflow.patch"

# Patch a legitimate bug in AMGX that we warn about.
sed -E \
  's/description\(p.description\), default_value\(default_value\)/description(p.description), default_value(p.default_value)/' \
  -i "${OUT_DIR}/AMGX/AMGX/include/amg_config.h"
