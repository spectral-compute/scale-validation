#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone ctranslate2 https://github.com/OpenNMT/CTranslate2.git "$(get_version ctranslate2)"
