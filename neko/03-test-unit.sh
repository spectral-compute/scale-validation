#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
# shellcheck source=util/env.sh
. "${SCRIPT_DIR}/util/env.sh"

# pFUnit unit tests. With the CUDA backend, the device_* suites exercise the kernels.
# Build the suites in parallel, then run them one at a time (each uses the GPU).
make -C neko -j"$(nproc)" check TESTS=
make -C neko check
