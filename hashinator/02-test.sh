#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

meson test -C hashinator/build
