#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

git -C stdgpu apply "${SCRIPT_DIR}/test-max-threads.patch"
