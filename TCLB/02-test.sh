#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

export OMPI_MCA_accelerator=cuda

cd "./TCLB" && ./CLB/d2q9/main ./example/flow/2d/karman.xml
