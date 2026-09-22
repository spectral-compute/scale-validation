#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone ggml https://github.com/ggml-org/ggml "$(get_version ggml)"
