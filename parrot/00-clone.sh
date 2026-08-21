#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone parrot https://github.com/NVlabs/parrot.git "$(get_version parrot)"
