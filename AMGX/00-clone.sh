#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone AMGX https://github.com/NVIDIA/AMGX.git "$(get_version AMGX)"
