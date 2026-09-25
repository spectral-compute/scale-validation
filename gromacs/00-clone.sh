#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone gromacs https://github.com/gromacs/gromacs.git "$(get_version gromacs)"
