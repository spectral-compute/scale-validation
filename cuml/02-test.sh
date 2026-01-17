#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd cuml/cuml
cd cpp/build
./test/ml # Single GPU algorithm tests
./test/ml_mg # Multi GPU algorithm tests, if --singlegpu was not used
./test/prims # ML Primitive function tests
