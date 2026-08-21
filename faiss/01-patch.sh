#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

for P in "${SCRIPT_DIR}"/*.patch; do
    (cd faiss && patch -p0 <"${P}")
done
