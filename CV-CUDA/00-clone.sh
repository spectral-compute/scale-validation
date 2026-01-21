#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash CV-CUDA https://github.com/CVCUDA/CV-CUDA.git "$(get_version CV-CUDA)"
