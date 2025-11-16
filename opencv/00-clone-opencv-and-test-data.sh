#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/opencv"
cd "${OUT_DIR}/opencv"
do_clone_hash opencv https://github.com/opencv/opencv.git "$(get_version opencv)"
do_clone_hash opencv_contrib https://github.com/opencv/opencv_contrib.git "$(get_version opencv_contrib)"
do_clone_hash opencv_extra https://github.com/opencv/opencv_extra.git "$(get_version opencv_extra)"
