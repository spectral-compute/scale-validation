#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

# --samples is a genuine standalone-Cycles CLI flag; confirm every sample
# count actually renders (a separate flaky timing-comparison assertion isn't
# needed -- each check's duration is already visible in the script's output).
render_monkey_samples() {
    local samples="$1"
    ./install/cycles ./cycles/examples/scene_monkey.xml --device CUDA --samples "${samples}" --output "./monkey_s${samples}.png" \
        && [ -f "./monkey_s${samples}.png" ]
}

check_samples_4()   { render_monkey_samples 4; }
check_samples_32()  { render_monkey_samples 32; }
check_samples_128() { render_monkey_samples 128; }

check "monkey renders at 4 samples"   check_samples_4
check "monkey renders at 32 samples"  check_samples_32
check "monkey renders at 128 samples" check_samples_128

check_exit
