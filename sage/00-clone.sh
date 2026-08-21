#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone sage https://github.com/spcl/sage.git "$(get_version sage)"
