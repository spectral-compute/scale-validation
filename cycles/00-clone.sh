#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone cycles https://projects.blender.org/blender/cycles.git "$(get_version cycles)"

git -C cycles submodule update --checkout --init lib/linux_x64
