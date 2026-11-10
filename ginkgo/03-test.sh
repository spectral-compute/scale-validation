#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Ginkgo's tests declare ctest resource requirements (cudagpu:1, cpu:N): without a spec, ctest -j
# would run every GPU test at once. Share device 0 between a few tests at a time.
cat >resources.json <<JSON
{
    "version": {"major": 1, "minor": 0},
    "local": [{
        "cudagpu": [{"id": "0", "slots": 4}],
        "cpu": [{"id": "0", "slots": $(nproc)}]
    }]
}
JSON

ctest --test-dir build --output-on-failure --no-tests=error --timeout 600 \
    -j "$(nproc)" --resource-spec-file "$(realpath resources.json)"
