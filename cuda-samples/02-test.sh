#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/cuda-samples/build/test"
