#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash thrust https://github.com/NVIDIA/thrust.git "$(get_version thrust)"
