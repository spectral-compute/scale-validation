#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone_hash gpu_jpeg2k https://github.com/ePirat/gpu_jpeg2k "$(get_version gpu_jpeg2k)"
