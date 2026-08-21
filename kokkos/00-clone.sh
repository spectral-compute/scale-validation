#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone kokkos https://github.com/kokkos/kokkos.git "$(get_version kokkos)"
