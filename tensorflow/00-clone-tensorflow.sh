#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

mkdir -p "${OUT_DIR}/tensorflow"
cd "${OUT_DIR}/tensorflow"

do_clone tensorflow https://github.com/tensorflow/tensorflow.git "$(get_version tensorflow)"
do_clone tensorboard https://github.com/tensorflow/tensorboard.git "$(get_version tensorflow-tensorboard)"
do_clone estimator https://github.com/tensorflow/estimator.git "$(get_version tensorflow-estimator)"
do_clone optimization https://github.com/tensorflow/model-optimization.git "$(get_version tensorflow-optimization)"
do_clone addons https://github.com/tensorflow/addons.git "$(get_version tensorflow-addons)"
do_clone metadata https://github.com/tensorflow/metadata.git "$(get_version tensorflow-metadata)"
do_clone datasets https://github.com/tensorflow/datasets.git "$(get_version tensorflow-datasets)"
do_clone models https://github.com/tensorflow/models.git "$(get_version tensorflow-models)"
