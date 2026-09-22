#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone gpusnek https://github.com/jndean/gpusnek.git "$(get_version gpusnek)"
