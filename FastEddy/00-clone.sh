#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone FastEddy https://github.com/NCAR/FastEddy-model.git "$(get_version FastEddy)"
