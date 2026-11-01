#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
. "$(dirname "$0")"/chapel.env

do_clone ChOp https://github.com/tcarneirop/ChOp.git "$(get_version ChOp)"

if [[ ! -d "${CHPL_HOME}" ]]; then
    curl -sSfL "https://github.com/chapel-lang/chapel/releases/download/${CHAPEL_VERSION}/chapel-${CHAPEL_VERSION}.tar.gz" | tar -xz
fi
