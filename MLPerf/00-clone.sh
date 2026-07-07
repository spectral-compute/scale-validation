#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone MLPerf https://github.com/spectral-compute/scale-mlperf.git "$(get_version MLPerf)"