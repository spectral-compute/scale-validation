#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone lightgbm https://github.com/microsoft/LightGBM.git v4.6.0
