#!/bin/bash

set -ETeuo pipefail

YOLO_UTILS_DIR="$(realpath ./yolo_utils)"
mkdir -p $YOLO_UTILS_DIR
if [ ! -e $YOLO_UTILS_DIR/yolov3-tiny.gguf ] ; then
    wget https://huggingface.co/rgerganov/yolo-gguf/resolve/main/yolov3-tiny.gguf -O $YOLO_UTILS_DIR/yolov3-tiny.gguf
fi

if [ ! -e $YOLO_UTILS_DIR/dog.jpg ] ; then
    wget https://raw.githubusercontent.com/pjreddie/darknet/master/data/dog.jpg -O $YOLO_UTILS_DIR/dog.jpg
fi

# Run it
cd ./ggml/examples/yolo
../../../build_ggml/bin/yolov3-tiny -m $YOLO_UTILS_DIR/yolov3-tiny.gguf -i $YOLO_UTILS_DIR/dog.jpg -o $YOLO_UTILS_DIR/predictions.jpg
