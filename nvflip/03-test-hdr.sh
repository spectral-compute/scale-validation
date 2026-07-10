#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

# flip-cuda initialises CUDA (cudaSetDevice(0)) unconditionally at startup,
# even just to print usage, so --help needs GPU access too.
check_help() {
    ./build/flip-cuda --help
}

check_hdr_flip() {
    ./build/flip-cuda --reference nvflip/images/reference.exr --test nvflip/images/test.exr --verbosity 1 \
        | grep -iE 'Mean:'
}

_tonemap_check() {
    local tm="$1"
    ./build/flip-cuda --reference nvflip/images/reference.exr --test nvflip/images/test.exr --verbosity 1 --tone-mapper "${tm}" \
        | grep -iE 'Mean:'
}

check_tonemap_aces()     { _tonemap_check ACES; }
check_tonemap_hable()    { _tonemap_check HABLE; }
check_tonemap_reinhard() { _tonemap_check REINHARD; }

check "--help smoke"                       check_help
check "HDR (.exr) comparison reports Mean" check_hdr_flip
check "tone-mapper ACES"                   check_tonemap_aces
check "tone-mapper HABLE"                  check_tonemap_hable
check "tone-mapper REINHARD"               check_tonemap_reinhard

check_exit
