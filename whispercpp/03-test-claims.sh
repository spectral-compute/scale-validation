#!/bin/bash
set -e
set -o pipefail

source "$(dirname "$0")"/../util/checks.sh

cd "whispercpp"

# Download the smaller and larger model sizes to check the "all model sizes"
# claim beyond the base.en model already exercised by 02-test.sh.
bash ./models/download-ggml-model.sh tiny.en
bash ./models/download-ggml-model.sh small.en

check_tiny_transcribes_jfk() {
    ../build/bin/main -m ./models/ggml-tiny.en.bin -f samples/jfk.wav &> jfk_tiny.out \
        && grep -qi 'Americans' jfk_tiny.out
}

check_small_transcribes_jfk() {
    ../build/bin/main -m ./models/ggml-small.en.bin -f samples/jfk.wav &> jfk_small.out \
        && grep -qi 'Americans' jfk_small.out
}

# At this pinned version, 'main' is the only CLI binary whisper.cpp builds
# (the whisper-cli rename/alias doesn't exist yet) -- just smoke-test --help.
check_main_help_smoke() {
    ../build/bin/main --help &> main_help.out \
        && grep -qi 'usage' main_help.out
}

check "tiny model transcribes jfk.wav correctly"  check_tiny_transcribes_jfk
check "small model transcribes jfk.wav correctly" check_small_transcribes_jfk
check "main --help smoke"                         check_main_help_smoke

check_exit
