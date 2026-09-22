#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone cuSZ https://github.com/szcompressor/cuSZ.git "$(get_version cuSZ)"
