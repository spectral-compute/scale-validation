#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone alien https://github.com/chrxh/alien.git "$(get_version alien)"

# do_clone uses --shallow-submodules by default to save space, but this makes vcpkg unhappy
git -C alien/external/vcpkg fetch --unshallow
