#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

PATCH=8

VER="$(get_version openmpi)"
DIR="openmpi-${VER//v/}.${PATCH}"
FILE="${DIR}.tar.bz2"

wget "https://download.open-mpi.org/release/open-mpi/${VER}/${FILE}"
tar -xf "${FILE}"

# Use a directory without a version in its name
rm -rf "source"
mv "${DIR}" "source"
