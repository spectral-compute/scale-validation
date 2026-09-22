#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

# Ensure we build google test with -fPIE, to avoid a link error
# shellcheck disable=SC2016
sed -i 's/cmake ../CXXFLAGS="${CXXFLAGS:-} -fPIE" cmake ../' jitify/Makefile
