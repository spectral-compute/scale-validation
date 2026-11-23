#!/usr/bin/env bash
# shellcheck disable=2317,2329
. "$(dirname "$0")"/../util/prelude.sh

source "$SCALE_VALIDATION/util/checks.sh"

LD_LIBRARY_PATH="$(realpath nccl/build/lib):${LD_LIBRARY_PATH-}"
export LD_LIBRARY_PATH

# One process drives every GPU (up to 8).
NGPUS="$(./gpu_count)"
if ((NGPUS > 8)); then
    NGPUS=8
fi
((NGPUS >= 1))
log "Testing NCCL with ${NGPUS} GPU(s)"

mkdir -p out

# run_nccl_test <log name> <test> [args]: -c 1 checks every result, and the summary counts the wrong values. Sizes
# in bytes: nccl-tests reads a size suffix (32M) with "%1s" into one char, so the NUL overruns it. A hang fails.
run_nccl_test() {
    local log="out/$1.log"
    local test="$2"
    shift 2
    timeout 600 nccl-tests/build/"${test}"_perf -b 8 -e 33554432 -f 4 -g "${NGPUS}" -c 1 "$@" &>"${log}"
    local rc=$?
    tail -n 25 "${log}"
    [[ "${rc}" == 0 ]] && grep -q '^# Out of bounds values : 0 OK' "${log}"
}

# Each protocol on its own (by default NCCL picks one by size).
run_all_reduce_proto() {
    NCCL_PROTO="$1" run_nccl_test "all_reduce-$1" all_reduce
}

for T in all_reduce all_gather reduce_scatter broadcast reduce sendrecv alltoall; do
    check "${T}" run_nccl_test "${T}" "${T}"
done

for P in LL LL128 Simple; do
    check "all_reduce, NCCL_PROTO=${P}" run_all_reduce_proto "${P}"
done

# CUDA graph mode: the iterations are captured and replayed (as vllm does at tensor parallelism > 1).
check "all_reduce, CUDA graphs" run_nccl_test all_reduce-graph all_reduce -G 10

check_exit
