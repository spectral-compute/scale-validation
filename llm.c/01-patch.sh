#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

cd "${OUT_DIR}/llm.c/llm.c"

git apply "${SCRIPT_DIR}/no-nvml.patch"
