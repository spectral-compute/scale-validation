#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

make -O -C jitify jitify_test NVCC="$(which nvcc)"
