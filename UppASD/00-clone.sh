#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone UppASD https://github.com/UppASD/UppASD.git "$(get_version UppASD)"
