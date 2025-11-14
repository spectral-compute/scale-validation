#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/whispercpp"
cd "${OUT_DIR}/whispercpp"

do_clone whispercpp https://github.com/ggerganov/whisper.cpp.git "$(cat "$(dirname $0)/version.txt" | grep "whispercpp" | sed "s/whispercpp //g")"
