#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

# If building on a different machine than running on, you can set NO_TUNE_NATIVE=1 to
# avoid SIGILL errors.
patch -p0 -d "UppASD" <"${SCRIPT_DIR}/honor_no_tune_native.patch"
