#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

mkdir -p .cache/colmap

# prefetch models into cache since we build with -DDOWNLOAD_ENABLED=false
wget -nc -nv -O .cache/colmap/aliked-n16rot.onnx \
    https://github.com/colmap/colmap/releases/download/3.13.0/aliked-n16rot.onnx
wget -nc -nv -O .cache/colmap/aliked-n32.onnx \
    https://github.com/colmap/colmap/releases/download/3.13.0/aliked-n32.onnx
wget -nc -nv -O .cache/colmap/aliked-lightglue.onnx \
    https://github.com/colmap/colmap/releases/download/3.13.0/aliked-lightglue.onnx
wget -nc -nv -O .cache/colmap/bruteforce-matcher.onnx \
    https://github.com/colmap/colmap/releases/download/3.13.0/bruteforce-matcher.onnx
wget -nc -nv -O .cache/colmap/sift-lightglue.onnx \
    https://github.com/colmap/colmap/releases/download/3.13.0/sift-lightglue.onnx
