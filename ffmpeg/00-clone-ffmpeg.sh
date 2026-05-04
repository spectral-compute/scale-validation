#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone nv-codec-headers https://github.com/FFmpeg/nv-codec-headers.git "n13.0.19.0"
do_clone ffmpeg https://github.com/FFmpeg/FFmpeg.git "$(get_version ffmpeg)"
