#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

while read -r F; do
    "${F}"
done < <(find install/bin/ -type f -executable)
