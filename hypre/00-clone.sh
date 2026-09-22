#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone hypre https://github.com/hypre-space/hypre.git "$(get_version hypre)"
