#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

PATCH=8

VER="$(get_version openmpi)"
DIR="openmpi-$(echo $VER | sed 's/v//g').${PATCH}"
FILE="${DIR}.tar.bz2"

wget "https://download.open-mpi.org/release/open-mpi/${VER}/${FILE}"
tar -xf "${FILE}"

# Use a directory without a version in its name
rm -rf "source"
mv "${DIR}" "source"
