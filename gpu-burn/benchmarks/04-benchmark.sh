#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# gpu-burn's own figure of merit: GFLOP/s per batch of SIZE=8192 GEMMs plus the comparison kernel.
# A fixed memory size keeps the batch the same across toolchains. Reports the median over each run,
# skipping the first few batches.
SECONDS_PER_RUN="${GPU_BURN_BENCHMARK_SECONDS:-60}"
OUT="${RESULTS_DIR:-$(realpath .)}/gpu-burn.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"

cd gpu-burn
echo "mode,median_gflops,batches" >"${OUT}"
for mode in float double; do
    flag=()
    [[ "${mode}" == double ]] && flag=(-d)
    ./gpu_burn "${flag[@]}" -i 0 -m 8192 "${SECONDS_PER_RUN}" | tr '\r' '\n' | tee "burn-${mode}.log"
    # Each progress line reports the latest batch's rate; a line whose count hasn't changed is a reprint.
    rates="$(sed -nE "s/.*proc'd: ([0-9]+) \(([0-9]+) Gflop\/s\).*/\1 \2/p" "burn-${mode}.log" |
        awk '$1 != prev { prev = $1; print $2 }' | tail -n +4)"
    n="$(echo "${rates}" | grep -c . || true)"
    if [[ "${n}" -lt 3 ]] || grep -qE 'FAULTY|DIED' "burn-${mode}.log"; then
        echo "No usable result for ${mode} (${n} batches)" >&2
        exit 1
    fi
    median="$(echo "${rates}" | sort -n | awk '{a[NR]=$1} END {print a[int((NR+1)/2)]}')"
    echo "${mode},${median},${n}" >>"${OUT}"
done
cat "${OUT}"
