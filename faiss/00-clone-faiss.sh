#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/faiss"
cd "${OUT_DIR}/faiss"

do_clone faiss https://github.com/facebookresearch/faiss.git "$(cat "$(dirname $0)/version.txt" | grep "faiss" | sed "s/faiss //g")"

# Dataset
wget -q https://data.spectralcompute.co.uk/faiss/sift.tar.gz
tar xf sift.tar.gz
mv sift sift1M
