#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone bitnet https://github.com/microsoft/BitNet.git "$(get_version bitnet)"
