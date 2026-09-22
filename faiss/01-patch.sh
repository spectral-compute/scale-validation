#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

for P in "${SCRIPT_DIR}"/*.patch; do
    (cd faiss && patch -p0 <"${P}")
done
