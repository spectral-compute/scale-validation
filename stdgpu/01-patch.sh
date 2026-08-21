#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

git -C stdgpu apply "${SCRIPT_DIR}/test-max-threads.patch"
