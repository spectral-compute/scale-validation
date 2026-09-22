#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

(cd ds4 && ./ds4-bench \
    -m ds4flash.gguf \
    --prompt-file speed-bench/promessi_sposi.txt \
    --ctx-start 2048 \
    --ctx-max 65536 \
    --step-incr 2048 \
    --gen-tokens 128)
