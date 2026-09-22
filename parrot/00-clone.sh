#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone parrot https://github.com/NVlabs/parrot.git "$(get_version parrot)"
