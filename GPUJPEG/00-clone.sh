#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash GPUJPEG https://github.com/CESNET/GPUJPEG "$(get_version GPUJPEG)"
