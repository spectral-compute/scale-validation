#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

git -C cuda-samples apply "${SCRIPT_DIR}/disable-stuff.patch"
