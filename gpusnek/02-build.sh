#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

make -O -C "gpusnek" -j"$(nproc)"
