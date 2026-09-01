#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone fasteddy https://github.com/NCAR/FastEddy-model.git "$(get_version fasteddy)"
