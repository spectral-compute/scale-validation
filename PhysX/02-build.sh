#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

./PhysX/physx/generate_projects.sh linux-clang

make -O -C ./PhysX/physx/compiler/linux-clang-checked -j"$(nproc)" -k
