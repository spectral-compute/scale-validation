#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

patch -p0 -d "caffe" < "${SCRIPT_DIR}/protobuf.patch"
