#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

cd "${OUT_DIR}/PhysX/PhysX/physx"

./generate_projects.sh linux-clang

cd compiler/linux-clang-checked

make -j$(nproc) -k
