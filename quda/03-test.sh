#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

while read -r F; do
    "${F}"
done < <(find install/bin/ -type f -executable)
