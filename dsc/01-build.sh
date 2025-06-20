#!/bin/bash

source "$(dirname "$0")"/../util/args.sh "$@"
cd "$OUT_DIR/dsc"

# build the C++ library with CUDA enabled
make clean; make shared DSC_FAST=1 DSC_CUDA=1
