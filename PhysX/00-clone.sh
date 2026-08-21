#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone PhysX https://github.com/NVIDIA-Omniverse/PhysX.git "$(get_version PhysX)"
