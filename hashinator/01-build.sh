#!/bin/bash

set -ETeuo pipefail

# Configure.
cd "hashinator"
mkdir subprojects
meson wrap install gtest
meson setup -Dwerror=false build --buildtype=release
meson compile -C build --jobs=8
cd -
