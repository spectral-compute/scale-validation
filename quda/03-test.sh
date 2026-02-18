#!/bin/bash

set -ETeuo pipefail

for F in $(find install/bin/ -type f -executable) ; do
    "${F}"
done
