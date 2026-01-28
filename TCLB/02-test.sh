#!/bin/bash

set -ETeuo pipefail
export OMPI_MCA_accelerator=cuda

cd "./TCLB"
./CLB/d2q9/main ./example/flow/2d/karman.xml
