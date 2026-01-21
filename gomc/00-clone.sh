#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash GOMC https://github.com/GOMC-WSU/GOMC.git "$(get_version gomc)"
do_clone_hash GOMC_Examples https://github.com/GOMC-WSU/GOMC_Examples.git "$(get_version GOMC_Examples)"
