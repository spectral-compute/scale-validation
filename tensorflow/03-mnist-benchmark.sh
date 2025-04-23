#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Create somewhere for results.
mkdir -p "${OUT_DIR}/tensorflow/benchmarks"
LOG_FILE="${OUT_DIR}/tensorflow/benchmarks/mnist.log"
RESULT_FILE="${OUT_DIR}/tensorflow/$(basename -s .sh "$0").csv"

# Tensorflow has its own way of downloading models that leaves them in a non-standard format.
mkdir -p "${OUT_DIR}/data/tensorflow"

# Do a timed run of an MNIST model.
export PYTHONPATH="$(echo "${OUT_DIR}"/tensorflow/install/usr/lib/python*/site-packages):${OUT_DIR}/tensorflow/models"
python3 "${OUT_DIR}/tensorflow/models/official/vision/image_classification/mnist_main.py" \
    --data_dir="${OUT_DIR}/data/tensorflow" \
    --train_epochs=10 \
    --download 2>&1 | tee "${LOG_FILE}"

# We don't need the intermediate downloaded data.
rm -rf "${OUT_DIR}/data/tensorflow/downloads"

# Extract the results.
START=$(grep -E 'Profiler session started' "${LOG_FILE}" | sed -E 's/: .*//')
END=$(grep -E 'Sets are not currently considered' "${LOG_FILE}" | sed -E 's/: .*//')
TIME=$(python3 "${SCRIPT_DIR}/IsoTimestampDiff.py" "${START}" "${END}" -1)
ACCURACY=$(grep -E 'accuracy_top_1' "${LOG_FILE}" | sed -E "s/.*'accuracy_top_1': ([0-9.]+),.*/\1/")

# Output the results.
echo "MNIST Training,time,${TIME}" > "${RESULT_FILE}"
echo "MNIST Model,accuracy,${ACCURACY}" >> "${RESULT_FILE}"

echo "MNIST Training Time: ${TIME} s"
echo "MNIST Model Accuracy: ${ACCURACY}"
