#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone gromacs https://github.com/gromacs/gromacs.git "$(get_version gromacs)"
