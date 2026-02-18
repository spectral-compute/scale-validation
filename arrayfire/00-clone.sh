#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone arrayfire https://github.com/arrayfire/arrayfire.git "$(get_version arrayfire)"
