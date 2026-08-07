#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone lammps https://github.com/lammps/lammps.git "$(get_version lammps)"
