#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

LD_LIBRARY_PATH="$(realpath nccl/build/lib):${LD_LIBRARY_PATH-}"
export LD_LIBRARY_PATH
# The GPUs one process drives (SCALE has no nvidia-smi to count them).
NGPUS="${NGPUS:-2}"

# -c 1 checks every result; the tests print the number of wrong values per collective.
for T in all_reduce all_gather reduce_scatter broadcast sendrecv; do
    nccl-tests/build/"${T}"_perf -b 8 -e 128M -f 4 -g "${NGPUS}" -c 1 | tee "${T}.log"
    grep -q '^# Out of bounds values : 0 OK' "${T}.log"
done
