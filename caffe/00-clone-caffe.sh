#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/caffe"
cd "${OUT_DIR}/caffe"
do_clone_hash caffe https://github.com/BVLC/caffe.git 9b891540183ddc834a02b2bd81b31afae71b2153
