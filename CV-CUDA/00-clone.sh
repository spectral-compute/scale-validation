#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone CV-CUDA https://github.com/CVCUDA/CV-CUDA.git "$(get_version CV-CUDA)"
