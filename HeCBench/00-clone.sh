#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# HeCBench requires `dvc` as part of its data management
# We recommend installing via pipx or uv
# See: https://doc.dvc.org/install/linux

do_clone HeCBench https://github.com/ORNL/HeCBench.git "$(get_version HeCBench)"

(cd HeCBench && dvc pull)
