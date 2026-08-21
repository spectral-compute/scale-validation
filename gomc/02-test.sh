#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

log "Testsuites are (report artifact set needs to match):"
log build/GOMC_GPU_*_Test

for F in build/GOMC_GPU_*_Test; do
    log "Running test $F"
    ./"${F}" --gtest_output="xml:$F.xml" --gtest_filter="-ConsistentTrajectoryTest.*"
done
