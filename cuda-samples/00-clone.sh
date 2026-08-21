#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone cuda-samples https://github.com/NVIDIA/cuda-samples.git "$(get_version cuda-samples)"
