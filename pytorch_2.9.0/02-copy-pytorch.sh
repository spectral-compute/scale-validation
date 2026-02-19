#!/bin/bash
set -euo pipefail

OUT_DIR="$(realpath .)"

SRC="${OUT_DIR}/pytorch_2.9.0"
BUILD="${SRC}/build"
DST="${BUILD}/pytorch_2.9.0"

rm -rf "${BUILD}"
mkdir -p "${DST}"

rsync -a --delete --exclude 'build/' "${SRC}/" "${DST}/"

cd "${DST}"
