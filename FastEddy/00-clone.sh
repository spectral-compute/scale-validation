#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone FastEddy https://github.com/NCAR/FastEddy-model.git "$(get_version FastEddy)"
