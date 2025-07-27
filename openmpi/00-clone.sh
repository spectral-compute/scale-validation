#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/openmpi"
cd "${OUT_DIR}/openmpi"

MAJOR=5
MINOR=0
PATCH=8

VER="v${MAJOR}.${MINOR}"
DIR="openmpi-${MAJOR}.${MINOR}.${PATCH}"
FILE="${DIR}.tar.bz2"

wget "https://download.open-mpi.org/release/open-mpi/${VER}/${FILE}"
tar -xf "${FILE}"

# Use a directory without a version in its name
rm -rf "source"
mv "${DIR}" "source"
