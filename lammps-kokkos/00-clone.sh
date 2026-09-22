#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone lammps-kokkos https://github.com/lammps/lammps "$(get_version lammps)"
