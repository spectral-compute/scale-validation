#!/usr/bin/env bash
# The base 01-build.sh (preset, SCALE disable list), but building only the
# benchmarks tools/hecbench run can time, i.e. those in subset.json.
HECBENCH_SUBSET_ONLY=1 exec bash "$(dirname "$0")"/../01-build.sh "$@"
