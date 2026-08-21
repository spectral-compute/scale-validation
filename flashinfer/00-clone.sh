#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone flashinfer https://github.com/flashinfer-ai/flashinfer.git "$(get_version flashinfer)"
