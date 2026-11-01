#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Embed labelled Gaussian clusters and check the embedding's quality.
PYTHONPATH="${PWD}/build/python" timeout 900 python3 "${SCRIPT_DIR}/quality.py"
