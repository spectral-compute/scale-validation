#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh
. "$(dirname "$0")"/../util/checks.sh

LD_LIBRARY_PATH="$(realpath ChOp/libs):${LD_LIBRARY_PATH:-}"
export LD_LIBRARY_PATH

# Number of N-Queens solutions, by board size.
declare -A SOLS=([10]=724 [12]=14200 [14]=365596 [15]=2279184 [16]=14772512 [17]=95815104)

# <binary> <size> <depth> <block size>: the cudaOnly programs check their own solution count.
check_cuda_only() {
    local out
    out="$("ChOp/NQueens/cudaOnly/$1" "$2" "$3" "$4")" || return 1
    echo "${out}"
    grep -q "SUCCESS - CORRECT NUMBER OF SOLS" <<<"${out}"
}

# <size> <depth> <CPU fraction>
check_chapel() {
    local out
    out="$(ChOp/bin/queens_CUDA_GPU_CPU_single_node.out --mode=mgpu --language=cuda \
        --size="$1" --initial_depth="$2" --CPUP="$3")" || return 1
    echo "${out}"
    grep -qx "Number of solutions: ${SOLS[$1]}" <<<"${out}"
}

for n in 10 12 15 16; do
    check "cudaOnly single-GPU, size ${n}" check_cuda_only singleGPUQueens "${n}" 5 128
done
for n in 12 16; do
    check "cudaOnly multi-GPU, size ${n}" check_cuda_only multiGPUQueens "${n}" 5 128
done
for n in 10 14 16; do
    check "Chapel+CUDA, size ${n}" check_chapel "${n}" 4 0.0
done
# Not tested: a nonzero --CPUP. That loses solutions whatever the GPU: GPU_mlocale_get_starting_point
# starts the GPU share at cpu_load+1, skipping a subproblem and reading one past the end.

check_exit
