#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

set -e

mkdir -p out

./build/hashcat --backend-ignore-hip --backend-ignore-opencl -b | tee out/benchmark-builtin-default.log
