#!/bin/bash

set -e

# Skip faulty benchmarks. See scale#385.
SKIP="stdgpu_unordered_.*_insert/.*
stdgpu_unordered_.*_erase/.*
stdgpu_unordered_.*_clear/.*"

SKIP=$(echo $SKIP | sed 's/ /|/g')

./build/bin/benchmarkstdgpu --benchmark_filter="-$SKIP" --benchmark_out_format=csv --benchmark_out=out.csv --v=3
