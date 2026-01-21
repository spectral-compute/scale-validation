#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

patch -p0 -d "GPUJPEG" < "${SCRIPT_DIR}/ld.patch"
