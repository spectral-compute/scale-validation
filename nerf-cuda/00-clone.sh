#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone nerf-cuda https://github.com/metaverse3d2022/Nerf-Cuda/ "$(get_version nerf-cuda)"
