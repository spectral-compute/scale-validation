#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../../util/args.sh "$@"

mkdir -p "${OUT_DIR}/llama-cpp-python"
cd "${OUT_DIR}/llama-cpp-python"
do_clone_hash llama-cpp-python https://github.com/abetlen/llama-cpp-python.git e1af05f43f57d2b660edfb77935dd2d2641ec602

