#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone whispercpp https://github.com/ggerganov/whisper.cpp.git "$(get_version whispercpp)"
