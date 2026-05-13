#!/bin/bash

set -e

FFMPEG="$(pwd)/install/bin/ffmpeg"

# Generate a synthetic 1080p input as mp4.
"${FFMPEG}" -y \
    -f lavfi -i testsrc=duration=5:size=2560x1440:rate=30 \
    -c:v mpeg4 \
    input.mp4

# CUDA scale filter: upload to GPU, scale, download.
"${FFMPEG}" -y \
    -i input.mp4 \
    -vf "format=nv12,hwupload_cuda,scale_cuda=1280:720,hwdownload,format=nv12" \
    -c:v mpeg4 \
    output.mp4

rm -f input.mp4 output.mp4
