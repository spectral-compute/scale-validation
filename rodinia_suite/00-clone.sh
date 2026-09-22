#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

# TODO: Figure out why we have a fork, and not do that
do_clone rodinia_suite https://github.com/manospavlidakis/rodinia_suite.git "$(get_version rodinia_suite)"
