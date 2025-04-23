#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/cycles"
cd "${OUT_DIR}/cycles"
do_clone cycles https://projects.blender.org/blender/cycles.git v4.4.0
cd cycles
git submodule update --checkout --init lib/linux_x64
