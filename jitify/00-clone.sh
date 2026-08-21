#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone jitify https://github.com/NVIDIA/jitify.git "$(get_version jitify)"
