#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone MAGMA https://github.com/icl-utk-edu/magma/ "$(get_version MAGMA)"
