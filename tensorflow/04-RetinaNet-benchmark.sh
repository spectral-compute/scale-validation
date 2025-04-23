#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PYTHONPATH="$(echo "${OUT_DIR}"/tensorflow/install/usr/lib/python*/site-packages):${OUT_DIR}/tensorflow/models"

# Create somewhere for results.
rm -rf "${OUT_DIR}/tensorflow/benchmarks/RetinaNet"
mkdir -p "${OUT_DIR}/tensorflow/benchmarks/RetinaNet"
LOG_FILE="${OUT_DIR}/tensorflow/benchmarks/RetinaNet/out.log"
RESULT_FILE="${OUT_DIR}/tensorflow/$(basename -s .sh "$0").csv"

# Tensorflow has its own way of downloading models that leaves them in a non-standard format.
mkdir -p "${OUT_DIR}/data/tensorflow"

# Download the dataset.
cd "${OUT_DIR}/data/tensorflow"
for URL in https://storage.googleapis.com/aihub-c2t-containers-public/release-0.2.0/kfp-components/oob_algorithm/retinanet/TEST_data/coco_tfrecords/train-subset.tfrecord \
           https://storage.googleapis.com/aihub-c2t-containers-public/release-0.2.0/kfp-components/oob_algorithm/retinanet/TEST_data/coco_tfrecords/val-subset.tfrecord \
           https://storage.googleapis.com/aihub-c2t-containers-public/release-0.2.0/kfp-components/oob_algorithm/retinanet/TEST_data/coco_tfrecords/instances_val2017.json ; do
    if [ ! -e "$(echo "${URL}" | sed -E 's;.*/;;')" ] ; then
        wget -q "${URL}"
    fi
done

# Do a timed run of a RetinaNet model using the COCO sample we just downloaded.
STEPS=1000
python3 "${OUT_DIR}/tensorflow/models/official/vision/detection/main.py" \
    --strategy_type=one_device \
    --num_gpus=1 \
    --mode=train \
    --model_dir="${OUT_DIR}/tensorflow/benchmarks/RetinaNet" \
    --params_override='eval:
 eval_file_pattern: "'${OUT_DIR}'/data/tensorflow/val-subset.tfrecord"
 batch_size: 1
 val_json_file: "'${OUT_DIR}'/data/tensorflow/instances_val2017.json"
predict:
 predict_batch_size: 1
architecture:
 use_bfloat16: False
train:
 total_steps: '${STEPS}'
 batch_size: 1
 train_file_pattern: "'${OUT_DIR}'/data/tensorflow/train-subset.tfrecord"
 learning_rate:
   warmup_learning_rate: 0.001
   init_learning_rate: 0.01
use_tpu: False
' 2>&1 | tee "${LOG_FILE}"

# Extract the results.
START=$(grep -E 'Successfully opened dynamic library' "${LOG_FILE}" | sed -E 's/: .*//')
END=$(grep -E 'read the dataset being cached' "${LOG_FILE}" | sed -E 's/: .*//')
TIME=$(python3 "${SCRIPT_DIR}/IsoTimestampDiff.py" "${START}" "${END}" -1)
LOSS=$(grep -E "Train Step: ${STEPS}/${STEPS}" "${LOG_FILE}" | sed -E "s/.*'total_loss': ([0-9.]+),.*/\1/")

# Output the results.
echo "RetinaNet Training,time,${TIME}" > "${RESULT_FILE}"
echo "RetinaNet Model,loss,${LOSS}" >> "${RESULT_FILE}"

echo "RetinaNet Training Time: ${TIME} s"
echo "RetinaNet Model Loss: ${LOSS}"
