#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone cycles https://projects.blender.org/blender/cycles.git "$(get_version cycles)"

git -C cycles submodule update --checkout --init lib/linux_x64
