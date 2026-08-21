#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cp -r --reflink=auto hashcat build

make -O -C build
