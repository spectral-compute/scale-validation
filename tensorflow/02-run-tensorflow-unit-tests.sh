#!/bin/bash

set -e
cd "build"

source "${SCRIPT_DIR}/config.sh"

set +e
bazel test --config=v2 //tensorflow/python/... -j 1 # Running in parallel exhausts GPU memory.
