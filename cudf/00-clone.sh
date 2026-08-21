#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone cudf https://github.com/rapidsai/cudf "$(get_version cudf)"
