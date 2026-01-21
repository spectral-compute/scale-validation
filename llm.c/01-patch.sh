#!/bin/bash

set -e

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

git -C llm.c apply "${SCRIPT_DIR}/no-nvml.patch"
