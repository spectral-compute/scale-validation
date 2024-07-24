#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/cutlass"
cd "${OUT_DIR}/cutlass"

do_clone cutlass https://github.com/NVIDIA/cutlass.git 7d49e6c7e2f8896c47f586706e67e1fb215529dc
