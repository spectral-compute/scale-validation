#!/usr/bin/env bash

set -euo

source "$(dirname "$0")"/../util/git.sh

do_clone cp2k https://github.com/cp2k/cp2k.git "$(get_version cp2k)"
