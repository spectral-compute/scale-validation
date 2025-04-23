#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"
cd "${OUT_DIR}/tensorflow/build"

source "${SCRIPT_DIR}/config.sh"

set +e
bazel test --config=v2 //tensorflow/python/... -j 1 # Running in parallel exhausts GPU memory.
if [ "$?" != "0" ] ; then
    exit 222
fi
