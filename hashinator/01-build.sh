#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Hashinator calls the CUDA 12 cudaMemPrefetchAsync (with an int device).
# TODO: Check whether a newer upstream release supports CUDA 13, so this can go.
export SCALE_CUDA_VERSION="12.8"

(cd "hashinator" &&
    mkdir subprojects &&
    meson wrap install gtest &&
    meson setup -Dwerror=false build --buildtype=release &&
    meson compile -C build --jobs=8)
