#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash rabbitct https://github.com/spectral-compute/RabbitCT "$(get_version rabbitct)"

cd rabbitct

# TODO: Find some way to cache this?
./download-input.sh <<< "y"