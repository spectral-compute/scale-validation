#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone opencv https://github.com/opencv/opencv.git "$(get_version opencv)"
do_clone opencv_contrib https://github.com/opencv/opencv_contrib.git "$(get_version opencv_contrib)"
do_clone opencv_extra https://github.com/opencv/opencv_extra.git "$(get_version opencv_extra)"
