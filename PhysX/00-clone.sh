#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash PhysX https://github.com/NVIDIA-Omniverse/PhysX.git "$(get_version PhysX)"
