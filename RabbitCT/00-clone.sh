#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash RabbitCT https://github.com/ipatix/RabbitCT "$(get_version RabbitCT)"

cd RabbitCT

# TODO: Find some way to cache this?
./download-input.sh <<< "y"