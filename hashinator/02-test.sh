#!/bin/bash

set -ETeuo pipefail

cd "hashinator/hashinator"

# Test.
meson test -C build

cd -
