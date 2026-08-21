#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

make -O -C "gpusnek" -j"$(nproc)"
