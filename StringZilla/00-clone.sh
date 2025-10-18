#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/StringZilla"
cd "${OUT_DIR}/StringZilla"

do_clone StringZilla https://github.com/ashvardanian/StringZilla.git v4.2.1
