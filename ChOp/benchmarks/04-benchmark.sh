#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Times the single-GPU N-Queens search in ChOp's standalone programs (NQueens/cudaOnly vs NQueens/hip,
# the same kernel source) and in the Chapel program. The Chapel program's CUDA kernel has a 32-entry
# board and its HIP kernel a 24-entry one, which makes the HIP kernel faster on AMD GPUs whatever the
# compiler, so compare the standalone programs across toolchains.
SIZE="${CHOP_BENCHMARK_SIZE:-17}"
DEPTH="${CHOP_BENCHMARK_DEPTH:-6}"
OUT="${RESULTS_DIR:-$(realpath .)}/ChOp.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"
LD_LIBRARY_PATH="$(realpath ChOp/libs):${LD_LIBRARY_PATH:-}"
export LD_LIBRARY_PATH

if [[ "${BENCHMARK_COMPILER:-}" == hip ]]; then
    standalone=ChOp/NQueens/hip/singleGPUQueens
    chapel=(ChOp/bin/queens_AMD_GPU_CPU_single_node.out --language=amd)
else
    standalone=ChOp/NQueens/cudaOnly/singleGPUQueens
    chapel=(ChOp/bin/queens_CUDA_GPU_CPU_single_node.out --language=cuda)
fi

# Number of N-Queens solutions, by board size.
declare -A SOLS=([15]=2279184 [16]=14772512 [17]=95815104 [18]=666090624)

echo "program,size,depth,seconds" >"${OUT}"

out="$("${standalone}" "${SIZE}" "${DEPTH}" 128)"
echo "${out}"
grep -q "SUCCESS - CORRECT NUMBER OF SOLS" <<<"${out}"
echo "standalone,${SIZE},${DEPTH},$(awk '/^Elapsed total:/ {print $NF}' <<<"${out}")" >>"${OUT}"

out="$("${chapel[@]}" --mode=mgpu --size="${SIZE}" --initial_depth="${DEPTH}")"
echo "${out}"
grep -qx "Number of solutions: ${SOLS[${SIZE}]}" <<<"${out}"
echo "chapel,${SIZE},${DEPTH},$(awk '/Final search el. time:/ {print $NF}' <<<"${out}")" >>"${OUT}"

cat "${OUT}"
