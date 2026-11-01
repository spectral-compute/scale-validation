#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Upstream's validation: t-SNE of 5000 random points must complete without errors or hanging.
PYTHONPATH="${PWD}/build/python" timeout 600 python3 -c 'import tsnecuda; tsnecuda.test()'
