#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash nvflip https://github.com/NVlabs/flip.git "$(get_version nvflip)"
