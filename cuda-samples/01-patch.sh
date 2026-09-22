#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

git -C cuda-samples apply "${SCRIPT_DIR}/disable-stuff.patch"
