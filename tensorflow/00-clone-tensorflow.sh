#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/tensorflow"
cd "${OUT_DIR}/tensorflow"

git clone https://github.com/tensorflow/tensorflow.git
git clone https://github.com/tensorflow/tensorboard.git
git clone https://github.com/tensorflow/estimator.git
git clone https://github.com/tensorflow/model-optimization.git
git clone https://github.com/tensorflow/addons.git
git clone https://github.com/tensorflow/metadata.git
git clone https://github.com/tensorflow/datasets.git
git clone https://github.com/tensorflow/models.git

cd "${OUT_DIR}/tensorflow/tensorflow"
git checkout v2.2.0

cd "${OUT_DIR}/tensorflow/tensorboard"
git checkout 2.2.0

cd "${OUT_DIR}/tensorflow/estimator"
git checkout v2.2.0

cd "${OUT_DIR}/tensorflow/model-optimization"
git checkout v0.3.0

cd "${OUT_DIR}/tensorflow/addons"
git checkout v0.10.0

cd "${OUT_DIR}/tensorflow/metadata"
git checkout v0.22.2

cd "${OUT_DIR}/tensorflow/datasets"
git checkout v3.1.0

cd "${OUT_DIR}/tensorflow/models"
git checkout v2.2.0
