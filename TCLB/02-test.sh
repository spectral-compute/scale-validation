#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

export OMPI_MCA_accelerator=cuda

cd "./TCLB" && ./CLB/d2q9/main ./example/flow/2d/karman.xml
