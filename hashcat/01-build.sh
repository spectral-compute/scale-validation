#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

cp -r --reflink=auto hashcat build

make -O -C build
