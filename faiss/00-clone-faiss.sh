#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/faiss"
cd "${OUT_DIR}/faiss"

do_clone faiss https://github.com/facebookresearch/faiss.git v1.9.0

# Dataset
wget -q https://data.spectralcompute.co.uk/faiss/sift.tar.gz
tar xf sift.tar.gz
mv sift sift1M
