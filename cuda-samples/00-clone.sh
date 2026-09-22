#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone cuda-samples https://github.com/NVIDIA/cuda-samples.git "$(get_version cuda-samples)"
