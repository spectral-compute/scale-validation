#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone thrust https://github.com/NVIDIA/thrust.git "$(get_version thrust)"
