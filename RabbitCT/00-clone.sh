#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone RabbitCT https://github.com/ipatix/RabbitCT "$(get_version RabbitCT)"