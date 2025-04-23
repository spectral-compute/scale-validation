#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/opencv"
cd "${OUT_DIR}/opencv"
do_clone_hash opencv https://github.com/opencv/opencv.git 725e440
do_clone_hash opencv_contrib https://github.com/opencv/opencv_contrib.git e247b68
do_clone_hash opencv_extra https://github.com/opencv/opencv_extra.git 5abbd7e
