#!/bin/bash

set -e

./PhysX/physx/generate_projects.sh linux-clang

make -C ./PhysX/physx/compiler/linux-clang-checked -j$(nproc) -k
