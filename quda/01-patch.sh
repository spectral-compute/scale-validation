#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

# Libstdc++ has become more strict about includes.
while read -r F; do
    sed '1s/^/#include <utility>\n/' -i "${F}"
done < <(grep 'std::exchange' quda/ -rn | sed -E 's/:.*//' | sort -u)
