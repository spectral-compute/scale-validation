#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

set -e

mkdir -p out

./build/hashcat --backend-ignore-hip --backend-ignore-opencl -b | tee out/benchmark-builtin-default.log
