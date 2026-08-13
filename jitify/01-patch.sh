#!/bin/bash

set -e

# Ensure we build google test with -fPIE, to avoid a link error
sed -i 's/cmake ../CXXFLAGS="${CXXFLAGS:-} -fPIE" cmake ../' jitify/Makefile
