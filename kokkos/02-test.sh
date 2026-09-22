#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

ctest --test-dir build/ -parallel 8 --verbose
