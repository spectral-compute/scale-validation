#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

(cd "hashinator" &&
    mkdir subprojects &&
    meson wrap install gtest &&
    meson setup -Dwerror=false build --buildtype=release &&
    meson compile -C build --jobs=8)
