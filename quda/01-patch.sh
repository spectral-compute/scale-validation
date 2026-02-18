#!/bin/bash

set -ETeuo pipefail

cd "quda"

# Libstdc++ has become more strict about includes.
for F in $(grep 'std::exchange' -rn | sed -E 's/:.*//' | sort -u) ; do
    sed '1s/^/#include <utility>\n/' -i "${F}"
done

cd -
