#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh
# shellcheck source=../util/env.sh
. "${SCRIPT_DIR}/../util/env.sh"

# Runs a few cases for a fixed number of steps and records the mean wall time per step, excluding the
# first WARMUP steps (kernel loading, time-scheme start-up).
STEPS="${NEKO_BENCHMARK_STEPS:-100}"
WARMUP=10
OUT="${RESULTS_DIR:-$(realpath .)}/neko.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"
NEKO_SRC="$(realpath neko)"

rm -rf bench
mkdir bench
cd bench

# <name> <case file> <mesh> <timestep, or - for the case's> [user file]
cases=(
    "tgv32 ${NEKO_SRC}/examples/tgv/tgv.case ${NEKO_SRC}/examples/tgv/32768.nmsh 1e-3 ${NEKO_SRC}/examples/tgv/tgv.f90"
    "hemi ${NEKO_SRC}/examples/hemi/hemi.case ${NEKO_SRC}/examples/hemi/hemi.nmsh -"
    "cylinder ${NEKO_SRC}/tests/integration/tests/test_cylinder/cylinder_part1.case ${NEKO_SRC}/tests/integration/meshes/small_test_cyl.nmsh -"
)

echo "case,steps,ms_per_step,wall_ms" >"${OUT}"
for c in "${cases[@]}"; do
    read -r name case mesh dt user <<<"${c}"
    mkdir "${name}"
    pushd "${name}" >/dev/null
    cp "${mesh}" .
    # Run a fixed number of steps, from a single mesh file in the working directory, without output.
    python3 - "${case}" "$(basename "${mesh}")" "${STEPS}" "${dt}" >case.json <<'PY'
import json, re, sys
src = open(sys.argv[1]).read()
c = json.loads(re.sub(r"^\s*//.*$", "", src, flags=re.M))["case"]
c["mesh_file"] = sys.argv[2]
dt = c["time"]["timestep"] if sys.argv[4] == "-" else float(sys.argv[4])
c["time"] = {"timestep": dt, "end_time": dt * (int(sys.argv[3]) + 0.5)}
c["output_checkpoints"] = False
c["output_boundary"] = False
c["output_at_end"] = False
c.get("fluid", {})["output_control"] = "never"
c["fluid"].pop("output_value", None)
print(json.dumps({"version": 1.0, "case": c}, indent=2))
PY
    exe=neko
    if [[ -n "${user}" ]]; then
        cp "${user}" .
        makeneko "$(basename "${user}")"
        exe=./neko
    fi
    start=$(date +%s%N)
    "${exe}" case.json | tee run.log
    end=$(date +%s%N)
    ms=$(awk -v w="${WARMUP}" '/Total time for step/ {if ($5 + 0 > w) {s += $NF; n++}} END {if (n) printf "%.3f", 1000 * s / n}' run.log)
    if [[ -z "${ms}" ]]; then
        echo "No step times from ${name}" >&2
        exit 1
    fi
    echo "${name},${STEPS},${ms},$(((end - start) / 1000000))" >>"${OUT}"
    popd >/dev/null
done
cat "${OUT}"
