#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone StringZilla https://github.com/ashvardanian/StringZilla.git "$(get_version StringZilla)"
