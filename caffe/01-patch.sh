#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

patch -p0 -d "${OUT_DIR}/caffe/caffe" < "${SCRIPT_DIR}/protobuf.patch"
