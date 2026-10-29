#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone hoomd-blue https://github.com/glotzerlab/hoomd-blue.git "$(get_version hoomd-blue)"
