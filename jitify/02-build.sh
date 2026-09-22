#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

make -O -C jitify jitify_test NVCC="$(which nvcc)"
