#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

cd ${OUT_DIR}/nerf-cuda
do_clone nerf-cuda https://github.com/metaverse3d2022/Nerf-Cuda/ "$(cat "$(dirname $0)/version.txt" | grep "nerf-cuda" | sed "s/nerf-cuda //g")"
