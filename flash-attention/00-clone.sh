#!/bin/bash
set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash flash-attention https://github.com/Dao-AILab/flash-attention.git "$(get_version flash-attention)"
