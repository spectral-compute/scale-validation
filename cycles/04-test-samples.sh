#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh

source "$SCALE_VALIDATION/util/checks.sh"

# --samples is a genuine standalone-Cycles CLI flag; confirm every sample
# count actually renders. How render time scales with samples is a
# performance question, covered by benchmarks/.
render_monkey_samples() {
    local samples="$1"
    ./install/cycles ./cycles/examples/scene_monkey.xml --device CUDA --samples "${samples}" --output "./monkey_s${samples}.png" &&
        [ -f "./monkey_s${samples}.png" ]
}

for SAMPLES in 4 32 128; do
    check "monkey renders at ${SAMPLES} samples" render_monkey_samples "${SAMPLES}"
done

check_exit
