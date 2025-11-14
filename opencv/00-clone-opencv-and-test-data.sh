#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/opencv"
cd "${OUT_DIR}/opencv"
do_clone_hash opencv https://github.com/opencv/opencv.git "$(cat "$(dirname $0)/version.txt" | grep "opencv" | sed "s/opencv //g")"
do_clone_hash opencv_contrib https://github.com/opencv/opencv_contrib.git "$(cat "$(dirname $0)/version.txt" | grep "opencv_contrib" | sed "s/opencv_contrib //g")"
do_clone_hash opencv_extra https://github.com/opencv/opencv_extra.git "$(cat "$(dirname $0)/version.txt" | grep "opencv_extra" | sed "s/opencv_extra //g")"
