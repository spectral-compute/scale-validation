#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone cudf https://github.com/rapidsai/cudf "$(get_version cudf)"
