#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/ctranslate2"
cd "${OUT_DIR}/ctranslate2"

do_clone ctranslate2 https://github.com/OpenNMT/CTranslate2.git "$(cat "$(dirname $0)/version.txt" | grep "ctranslate2" | sed "s/ctranslate2 //g")"
