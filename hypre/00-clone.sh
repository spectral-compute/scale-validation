#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone hypre https://github.com/hypre-space/hypre.git "$(get_version hypre)"
