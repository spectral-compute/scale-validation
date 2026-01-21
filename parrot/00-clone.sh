#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash parrot https://github.com/NVlabs/parrot.git c88d995
