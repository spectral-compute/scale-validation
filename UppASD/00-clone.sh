#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone UppASD https://github.com/UppASD/UppASD.git "$(get_version UppASD)"
