#!/bin/bash

set -ETeuo pipefail

# Test.
meson test -C hashinator/build
