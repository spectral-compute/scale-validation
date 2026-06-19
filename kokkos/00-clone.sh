#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone kokkos https://github.com/kokkos/kokkos.git "$(get_version kokkos)"
