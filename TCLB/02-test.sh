#!/bin/bash

set -ETeuo pipefail
export OMPI_MCA_accelerator=cuda

cd "${OUT_DIR}/TCLB/TCLB"
TCLB/CLB/d2q9/main TCLB/example/flow/2d/karman.xml
