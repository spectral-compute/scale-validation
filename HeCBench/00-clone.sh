#!/bin/bash
set -euo pipefail
# HeCBench requires `dvc` as part of its data management
# We recommend installing via pipx or uv
# See: https://doc.dvc.org/install/linux

source "$(dirname "$0")"/../util/git.sh

do_clone_hash HeCBench https://github.com/ORNL/HeCBench.git "$(get_version HeCBench)"

pushd HeCBench
dvc pull
popd
