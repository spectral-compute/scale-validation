#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone lammps-kokkos https://github.com/lammps/lammps "$(get_version lammps)"
