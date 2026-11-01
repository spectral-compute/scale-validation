#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone neko https://github.com/ExtremeFLOW/neko.git "$(get_version neko)"
do_clone json-fortran https://github.com/ExtremeFLOW/json-fortran.git "$(get_version neko-json-fortran)"
do_clone pFUnit https://github.com/Goddard-Fortran-Ecosystem/pFUnit.git "$(get_version neko-pFUnit)"
