#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

git -C llm.c apply "${SCRIPT_DIR}/no-nvml.patch"
