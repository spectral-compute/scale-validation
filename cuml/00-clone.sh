#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone cuml https://github.com/rapidsai/cuml.git "$(get_version cuml)"
