#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone ggml https://github.com/ggml-org/ggml "$(get_version ggml)"
