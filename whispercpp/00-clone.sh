#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone whispercpp https://github.com/ggerganov/whisper.cpp.git "$(get_version whispercpp)"
