#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Upstream bug (fixed after v0.2.0): the host seeds the managed graph while the asynchronous
# cudaMemset that zeroes it may still be running.
patch -p1 -d ScalingElections <"${SCRIPT_DIR}/memset-sync.patch"
