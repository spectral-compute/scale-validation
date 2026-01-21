#!/bin/bash

set -e

# We have to copy so the late stages of setup.py build work.
rm -rf "build"
cp -r --reflink=auto "pytorch" "build"

# (This also makes patching easier)
