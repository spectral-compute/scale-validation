#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd ScalingElections
. .venv/bin/activate

# Upstream's driver checks every backend against its serial Numba baseline, and reports a
# mismatch or a failure without changing its exit status. 128 candidates go through
# build_pairwise_preferences (2000 voters). v0.2.0's tiled solvers need the candidate count to
# be a multiple of the tile size (16 on the CPU, 32 on the GPU), like all its examples.
for args in "--num-candidates 128" "--num-candidates 512 --num-voters 0" "--num-candidates 2048 --num-voters 0"; do
    # shellcheck disable=SC2086
    python scaling_elections.py ${args} --run-cpu --run-gpu --warmup 0 --repeat 1 | tee out.log
    if grep -q "✗" out.log || [[ "$(grep -c "✓ Results validated" out.log)" != 4 ]]; then
        log "FAIL: ${args}"
        exit 1
    fi
done
