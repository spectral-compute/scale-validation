#!/usr/bin/env bash
set -euo pipefail
# Requires dvc
#   sudo apt install -y pipx
#   pipx ensurepath
#   pipx install dvc
#   pipx inject dvc dvc-s3

source "$(dirname "$0")"/../util/git.sh

do_clone_hash HeCBench https://github.com/ORNL/HeCBench.git "$(get_version HeCBench)"

(
    cd HeCBench
    dvc pull
    # The following does not compile even for cuda-nvidia
    rm -rf dp4a-cuda
)
