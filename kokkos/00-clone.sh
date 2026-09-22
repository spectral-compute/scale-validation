#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone kokkos https://github.com/kokkos/kokkos.git "$(get_version kokkos)"
