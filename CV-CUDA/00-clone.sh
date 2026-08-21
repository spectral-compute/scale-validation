#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone CV-CUDA https://github.com/CVCUDA/CV-CUDA.git "$(get_version CV-CUDA)"
