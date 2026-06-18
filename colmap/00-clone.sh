#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")"/../util/git.sh
do_clone colmap https://github.com/colmap/colmap "$(get_version colmap)"
