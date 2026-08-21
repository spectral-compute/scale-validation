#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone nv-codec-headers https://github.com/FFmpeg/nv-codec-headers.git "$(get_version nv-codec-headers)"
do_clone ffmpeg https://github.com/FFmpeg/FFmpeg.git "$(get_version ffmpeg)"
