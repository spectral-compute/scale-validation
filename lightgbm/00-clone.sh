#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone lightgbm https://github.com/lightgbm-org/LightGBM.git "$(get_version lightgbm)"
