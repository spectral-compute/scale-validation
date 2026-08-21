#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone cuSZ https://github.com/szcompressor/cuSZ.git "$(get_version cuSZ)"
