#!/usr/bin/env bash

set -euo

build/bin/cp2k.ssmp --version | tee cp2k-version.txt
grep -q "offload_cuda" cp2k-version.txt
