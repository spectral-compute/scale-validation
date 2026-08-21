#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

git -C llm.c apply "${SCRIPT_DIR}/no-nvml.patch"
