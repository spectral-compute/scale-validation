#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/whispercpp"
cd "${OUT_DIR}/whispercpp"

do_clone whispercpp https://github.com/ggerganov/whisper.cpp.git v1.7.1
