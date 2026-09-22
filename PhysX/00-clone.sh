#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone PhysX https://github.com/NVIDIA-Omniverse/PhysX.git "$(get_version PhysX)"
