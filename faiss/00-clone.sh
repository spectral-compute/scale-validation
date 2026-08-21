#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone faiss https://github.com/facebookresearch/faiss.git "$(get_version faiss)"

# Dataset
wget -q https://data.spectralcompute.co.uk/faiss/sift.tar.gz
tar xf sift.tar.gz
mv sift sift1M
