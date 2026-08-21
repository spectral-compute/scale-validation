#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

patch -p0 -d gpusnek <"${SCRIPT_DIR}/no_hardcoded_nvcc.patch"
