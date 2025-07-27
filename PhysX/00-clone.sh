#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/PhysX"
cd "${OUT_DIR}/PhysX"

do_clone_hash PhysX https://github.com/NVIDIA-Omniverse/PhysX.git 107.3-physx-5.6.1

