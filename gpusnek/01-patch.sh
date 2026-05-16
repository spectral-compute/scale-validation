#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
patch -p0 -d gpusnek < "${SCRIPT_DIR}/no_hardcoded_nvcc.patch"
