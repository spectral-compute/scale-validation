#!/usr/bin/env bash

set -euo pipefail

ulimit -s unlimited

./build/bonsai2_slowdust -i build/model3_child_compact.tipsy -T 1
