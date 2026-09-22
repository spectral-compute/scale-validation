#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

mkdir -p out
./build/hashcat --backend-ignore-hip --backend-ignore-opencl -m 1400 -b | tee out/benchmark-builtin-sha256.log
