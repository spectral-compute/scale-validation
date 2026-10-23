#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh

source "$SCALE_VALIDATION/util/checks.sh"

# CPU-vs-GPU comparison needs ImageMagick's compare, plus python3.
for TOOL in compare python3; do
    if ! command -v "${TOOL}" >/dev/null; then
        log "${TOOL} not found (install imagemagick/python3)"
        exit 1
    fi
done

# Render a bundled example on CPU and CUDA, and check the CUDA render matches
# the CPU reference. Timing lives in benchmarks/, not here.
render_matches_cpu() {
    local example="$1"
    local in="./cycles/examples/scene_${example}.xml"
    local cpu_out="./${example}_cpu.png"
    local cuda_out="./${example}_cuda.png"
    local mse

    ./install/cycles "${in}" --device CPU --output "${cpu_out}" &&
        ./install/cycles "${in}" --device CUDA --output "${cuda_out}" ||
        return 1

    mse="$(compare -metric mse "${cpu_out}" "${cuda_out}" /dev/null 2>&1 | head -n 1 | cut -f 1 -d ' ')"
    log "MSE vs CPU: ${mse}"
    [ "$(echo "print(${mse} < 0.01)" | python3)" == "True" ]
}

for EXAMPLE in cube_surface cube_volume monkey sphere_bump; do
    check "${EXAMPLE}: CUDA render matches CPU" render_matches_cpu "${EXAMPLE}"
done

check_exit
