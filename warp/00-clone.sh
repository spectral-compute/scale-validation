#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash warp  https://github.com/NVIDIA/warp.git "$(get_version warp)"
