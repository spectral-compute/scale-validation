#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone cycles https://projects.blender.org/blender/cycles.git "$(get_version cycles)"

git -C cycles submodule update --checkout --init lib/linux_x64
