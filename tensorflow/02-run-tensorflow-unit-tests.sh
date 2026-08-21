#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd "build"

source "${SCRIPT_DIR}/config.sh"

set +e
bazel test --config=v2 //tensorflow/python/... -j 1 # Running in parallel exhausts GPU memory.
