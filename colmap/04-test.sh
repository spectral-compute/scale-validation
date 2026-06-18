#!/usr/bin/env bash

set -euo pipefail

export HOME=$PWD
ctest --output-on-failure -j$(nproc)
