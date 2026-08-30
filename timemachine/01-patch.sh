#!/bin/bash

set -e

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

git -C timemachine apply "${SCRIPT_DIR}/cuda-flags-rdc.patch"
