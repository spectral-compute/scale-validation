#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone flashinfer https://github.com/flashinfer-ai/flashinfer.git "$(get_version flashinfer)"
