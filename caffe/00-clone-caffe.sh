#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/caffe"
cd "${OUT_DIR}/caffe"
do_clone_hash caffe https://github.com/BVLC/caffe.git "$(cat "$(dirname $0)/version.txt" | grep "caffe" | sed "s/caffe //g")"
