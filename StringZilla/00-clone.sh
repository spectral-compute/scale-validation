#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone StringZilla https://github.com/ashvardanian/StringZilla.git "$(get_version StringZilla)"
