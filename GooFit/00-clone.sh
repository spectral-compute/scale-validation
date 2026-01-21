#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone GooFit https://github.com/GooFit/GooFit.git "$(get_version GooFit)"
