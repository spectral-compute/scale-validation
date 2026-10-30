#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Runs each problem for a fixed number of steps, without output, with HARD's benchmark mode, which
# times each cycle. Records the median cycle time (lower is better) and the total.
STEPS="${HARD_BENCHMARK_STEPS:-50}"
OUT="${RESULTS_DIR:-$(realpath .)}/hard.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"
PROBLEMS="$(realpath "$(dirname "$0")"/problems.txt)"

if [ ! -d build-bench ]; then
    HARD_BUILD_DIR=build-bench HARD_BENCHMARK_MODE=ON "$(dirname "$0")"/../02-build.sh
fi

mkdir -p bench
cd bench
echo "problem,median_cycle_ms,total_s" >"${OUT}"
# problems.txt lines are "<name> <app> <dimension> <config> <levels>".
while read -r name app dim config levels <&3; do
    cat >"${name}.py" <<PY
exec(open("../HARD/configs/${config}").read())
config.update(levels=[${levels}], max_steps=${STEPS}, tf=1e30, log_frequency=${STEPS},
              output_frequency=10 * ${STEPS})
# Upstream's multi-material examples predate the per-material mean_molecular_weight.
for eos in config.get("eos_list", []):
    eos.setdefault("mean_molecular_weight", config["mean_molecular_weight"])
PY
    rm -rf result && mkdir result
    mpiexec -n 1 ../build-bench/apps/"${app}"/"${app}" "${name}.py" -d"${dim}" | tail -3
    # result/runtimes.txt: "processes;threads;max_iterations;total_runtime;<cycle seconds>;...;"
    python3 - "${name}" result/runtimes.txt >>"${OUT}" <<'PY'
import statistics, sys
fields = [f for f in open(sys.argv[2]).read().split(";") if f.strip()]
cycles = [float(f) for f in fields[4:]]
print(f"{sys.argv[1]},{statistics.median(cycles) * 1e3:.4f},{float(fields[3]):.3f}")
PY
done 3<"${PROBLEMS}"
cat "${OUT}"
