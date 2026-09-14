#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone lammps https://github.com/lammps/lammps "$(get_version lammps)"
