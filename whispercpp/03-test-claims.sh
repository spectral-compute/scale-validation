#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh

source "$SCALE_VALIDATION/util/checks.sh"

cd "whispercpp"

# Download the smaller and larger model sizes to check the "all model sizes"
# claim beyond the base.en model already exercised by 02-test.sh.
bash ./models/download-ggml-model.sh tiny.en
bash ./models/download-ggml-model.sh small.en

check_tiny_transcribes_jfk() {
    ../build/bin/whisper-cli -m ./models/ggml-tiny.en.bin -f samples/jfk.wav &>jfk_tiny.out &&
        grep -qi 'Americans' jfk_tiny.out
}

check_small_transcribes_jfk() {
    ../build/bin/whisper-cli -m ./models/ggml-small.en.bin -f samples/jfk.wav &>jfk_small.out &&
        grep -qi 'Americans' jfk_small.out
}

# Just smoke-test --help.
check_cli_help_smoke() {
    ../build/bin/whisper-cli --help &>cli_help.out &&
        grep -qi 'usage' cli_help.out
}

check "tiny model transcribes jfk.wav correctly" check_tiny_transcribes_jfk
check "small model transcribes jfk.wav correctly" check_small_transcribes_jfk
check "whisper-cli --help smoke" check_cli_help_smoke

check_exit
