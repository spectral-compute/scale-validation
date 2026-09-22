#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone CUDALibrarySamples https://github.com/NVIDIA/CUDALibrarySamples.git "$(get_version CUDALibrarySamples)"
