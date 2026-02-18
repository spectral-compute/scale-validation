#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash hashcat https://github.com/hashcat/hashcat.git "$(get_version hashcat)"
