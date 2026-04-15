#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash CUDALibrarySamples https://github.com/NVIDIA/CUDALibrarySamples.git "$(get_version CUDALibrarySamples)"
