#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone ds4 https://github.com/antirez/ds4.git "main"
