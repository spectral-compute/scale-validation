#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone cugraph https://github.com/rapidsai/cugraph "$(get_version cugraph)"
