#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone CUDALibrarySamples https://github.com/NVIDIA/CUDALibrarySamples.git "$(get_version CUDALibrarySamples)"
