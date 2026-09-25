#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone cuml https://github.com/rapidsai/cuml.git "$(get_version cuml)"
