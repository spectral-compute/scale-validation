#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone risc0 https://github.com/risc0/risc0.git "$(get_version risc0)"
