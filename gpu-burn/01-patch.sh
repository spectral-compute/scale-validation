#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Upstream bug: without a working nvidia-smi (as on AMD GPUs), the temperature pipe hits EOF and
# updateTemps() scans its uninitialised stack buffer for a newline, overrunning it (segfault).
git -C gpu-burn apply "${SCRIPT_DIR}/temp-eof.patch"
