#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
export OMPI_MCA_accelerator=cuda

cd "${OUT_DIR}/TCLB/TCLB"
CLB/d2q9/main example/flow/2d/karman.xml
