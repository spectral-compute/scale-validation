#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/stdgpu"

# Skip faulty benchmarks. See scale#385.
SKIP="
stdgpu_unordered_map_insert/10000000
stdgpu_unordered_map_erase/10000000
stdgpu_unordered_map_clear/10000000
stdgpu_unordered_map_erase/100000
stdgpu_unordered_set_insert/.*
stdgpu_unordered_set_erase/.*
stdgpu_unordered_set_clear/.*
"

SKIP=$(echo $SKIP | sed 's/ /|/g')

build/bin/benchmarkstdgpu --benchmark_filter="-$SKIP"
