#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Wall-clock seconds to render each bundled example scene (the ones that render something:
# scene_caustics and scene_world_volume are black on every device in v5.2.0) at a fixed sample
# count and resolution, using Cycles' CUDA device, or its HIP device for the native baseline.
SAMPLES="${CYCLES_BENCHMARK_SAMPLES:-1024}"
OUT="${RESULTS_DIR:-$(realpath .)}/cycles.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"

DEVICE=CUDA
if [[ "${BENCHMARK_COMPILER:-}" == hip ]]; then
    DEVICE=HIP
fi

echo "scene,samples,seconds" >"${OUT}"
for SCENE in monkey cube_surface cube_volume sphere_bump; do
    START="$(date +%s.%N)"
    ./install/cycles "./cycles/examples/scene_${SCENE}.xml" --device "${DEVICE}" --samples "${SAMPLES}" \
        --width 1280 --height 720 --background --quiet --output "./bench_${SCENE}.png"
    END="$(date +%s.%N)"
    echo "${SCENE},${SAMPLES},$(python3 -c "print(round(${END} - ${START}, 3))")" >>"${OUT}"
done
cat "${OUT}"
