#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
. "$(dirname "$0")"/chapel.env

make -C "${CHPL_HOME}" -j"$(nproc)"
