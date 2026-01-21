#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone cuda-samples https://github.com/NVIDIA/cuda-samples.git "$(get_version cuda-samples)"

git -C cuda-samples apply "${SCRIPT_DIR}/disable-stuff.patch"
