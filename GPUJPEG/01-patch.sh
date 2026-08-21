#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

patch -p0 -d "GPUJPEG" <"${SCRIPT_DIR}/ld.patch"
