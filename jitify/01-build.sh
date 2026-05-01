#!/bin/bash

set -ETeuo pipefail

make -O -C jitify jitify_test NVCC="$(which nvcc)"
