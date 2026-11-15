#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# The base 03-benchmark-builtin-sha256.sh on ROCm's native backends instead of
# hashcat's CUDA one. The log's first line records which backend ran, since
# HIP falls back to OpenCL (see util/hip-backend.sh).
source "$(dirname "$0")/util/hip-backend.sh"
mkdir -p out
LOG=out/benchmark-builtin-sha256.log
echo "# hashcat backend: ${HASHCAT_BACKEND}" | tee "${LOG}"
./build/hashcat "${HASHCAT_BACKEND_ARGS[@]}" -m 1400 -b | tee -a "${LOG}"
