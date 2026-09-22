#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone lammps https://github.com/lammps/lammps "$(get_version lammps)"
