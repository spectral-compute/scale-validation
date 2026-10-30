#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Runs each problem for a fixed number of steps without output, and records quokka's own figure of merit
# (microseconds per zone update, lower is better).
STEPS="${QUOKKA_BENCHMARK_STEPS:-100}"
OUT="${RESULTS_DIR:-$(realpath .)}/quokka.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"

echo "problem,us_per_zone_update,wall_ms" >"${OUT}"
PROBLEMS="$(realpath "$(dirname "$0")"/problems.txt)"
cd quokka/tests
# problems.txt lines are "<target> <input>".
while read -r target p <&3; do
    start=$(date +%s%N)
    # A truncated run fails the problem's own correctness check, so its exit status is ignored.
    ../../build/src/problems/"${target}"/"${target}" ../inputs/"${p}".toml max_timesteps="${STEPS}" \
        plotfile_interval=-1 checkpoint_interval=-1 | tee "${p}.bench.log" || true
    end=$(date +%s%N)
    fom=$(sed -nE 's/^Performance figure-of-merit: ([0-9.e+-]+) .*/\1/p' "${p}.bench.log")
    if [[ -z "${fom}" ]]; then
        echo "No figure of merit from ${p}" >&2
        exit 1
    fi
    echo "${p},${fom},$(((end - start) / 1000000))" >>"${OUT}"
done 3<"${PROBLEMS}"
cat "${OUT}"
