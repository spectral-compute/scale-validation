#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone ctranslate2 https://github.com/OpenNMT/CTranslate2.git "$(get_version ctranslate2)"
