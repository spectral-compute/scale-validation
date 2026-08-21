#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone gpusnek https://github.com/jndean/gpusnek.git "$(get_version gpusnek)"
