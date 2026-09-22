#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone StringZilla https://github.com/ashvardanian/StringZilla.git "$(get_version StringZilla)"
