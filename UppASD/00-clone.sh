#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone UppASD https://github.com/UppASD/UppASD.git "$(get_version UppASD)"
