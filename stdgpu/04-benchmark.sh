#!/bin/bash

set -e

# Skip faulty benchmarks. See scale#385.
SKIP="stdgpu_unordered_map_insert/10000000
stdgpu_unordered_map_erase/10000000
stdgpu_unordered_map_clear/10000000
stdgpu_unordered_map_erase/100000
stdgpu_unordered_set_insert/.*
stdgpu_unordered_set_erase/.*
stdgpu_unordered_set_clear/.*"

SKIP=$(echo $SKIP | sed 's/ /|/g')

# TODO: I think this isn't excluding the above list properly?
# ./build/bin/benchmarkstdgpu --benchmark_filter="(?!$SKIP)" --benchmark_out_format=csv --benchmark_out=out.csv
