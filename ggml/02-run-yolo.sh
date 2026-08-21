#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

YOLO_UTILS_DIR="$(realpath ./yolo_utils)"
mkdir -p "$YOLO_UTILS_DIR"

wget -nc -nv https://huggingface.co/rgerganov/yolo-gguf/resolve/main/yolov3-tiny.gguf -O "$YOLO_UTILS_DIR/yolov3-tiny.gguf"
wget -nc -nv https://raw.githubusercontent.com/pjreddie/darknet/master/data/dog.jpg -O "$YOLO_UTILS_DIR/dog.jpg"

# Run it
cd ./ggml/examples/yolo
../../../build_ggml/bin/yolov3-tiny -m "$YOLO_UTILS_DIR/yolov3-tiny.gguf" -i "$YOLO_UTILS_DIR/dog.jpg" -o "$YOLO_UTILS_DIR/predictions.jpg"
