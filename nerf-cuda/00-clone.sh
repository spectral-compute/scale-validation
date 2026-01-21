#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone nerf-cuda https://github.com/metaverse3d2022/Nerf-Cuda/ "$(get_version nerf-cuda)"
