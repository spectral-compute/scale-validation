#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# If building on a different machine than running on, you can set NO_TUNE_NATIVE=1 to
# avoid SIGILL errors.
patch -p0 -d "UppASD" < "${SCRIPT_DIR}/honor_no_tune_native.patch"
