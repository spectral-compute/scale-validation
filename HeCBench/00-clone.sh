#!/bin/bash
set -euo pipefail
# HeCBench requires `dvc` as part of its data management
#
# You can install this via `pipx`:
#   sudo apt install -y pipx
#   pipx ensurepath
#   pipx install dvc
#   pipx inject dvc dvc-s3
#
# or `uv`:
#   curl -LsSf https://astral.sh/uv/install.sh | sh
#   uv tool install dvc[s3]

# TODO: What can we assume is installed on the running machine?
# TODO: Uncomment if fine to install dependencies like this,
#       else document.
# if which uv &> /dev/null; then
#     curl -LsSf https://astral.sh/uv/install.sh | sh
#     uv tool install dvc[s3]
# fi

source "$(dirname "$0")"/../util/git.sh

do_clone_hash HeCBench https://github.com/ORNL/HeCBench.git "$(get_version HeCBench)"

(
    cd HeCBench
    
    dvc pull
)
