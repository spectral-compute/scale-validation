#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

mkdir -p "${OUT_DIR}/cuda-samples"
cd "${OUT_DIR}/cuda-samples"

do_clone cuda-samples https://github.com/NVIDIA/cuda-samples.git "$(cat "$(dirname $0)/version.txt" | grep "cuda-samples" | sed "s/cuda-samples //g")"

cd "${OUT_DIR}/cuda-samples/cuda-samples"
git apply "${SCRIPT_DIR}/disable-stuff.patch"
