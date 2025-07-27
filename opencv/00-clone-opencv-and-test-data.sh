#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/opencv"
cd "${OUT_DIR}/opencv"
do_clone_hash opencv https://github.com/opencv/opencv.git 4.12.0
do_clone_hash opencv_contrib https://github.com/opencv/opencv_contrib.git 4.12.0
do_clone_hash opencv_extra https://github.com/opencv/opencv_extra.git 4.12.0
