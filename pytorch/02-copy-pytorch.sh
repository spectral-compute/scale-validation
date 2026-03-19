#!/bin/bash
set -euo pipefail

OUT_DIR="$(realpath .)"

SRC="${OUT_DIR}/pytorch"
BUILD="${SRC}/build"
DST="${BUILD}/pytorch"

rm -rf "${BUILD}"
mkdir -p "${DST}"

rsync -a --delete --exclude 'build/' "${SRC}/" "${DST}/"

cd "${DST}"
