#!/bin/bash

set -e

mkdir -p out

./build/hashcat --backend-ignore-hip --backend-ignore-opencl -b | tee out/benchmark-builtin-default.log
