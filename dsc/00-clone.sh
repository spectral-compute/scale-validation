#!/bin/bash

source "$(dirname "$0")"/../util/args.sh "$@"
cd "$OUT_DIR"

# clone the repo
git clone https://github.com/nirw4nna/dsc.git
