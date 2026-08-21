#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

mkdir -p out
./build/hashcat --backend-ignore-hip --backend-ignore-opencl -m 1400 -b | tee out/benchmark-builtin-sha256.log
