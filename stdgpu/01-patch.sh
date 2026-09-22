#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

git -C stdgpu apply "${SCRIPT_DIR}/test-max-threads.patch"
