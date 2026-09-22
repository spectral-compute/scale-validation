#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

./build/src/nova++ ./heraclespp/inputs/rayleigh_taylor3d.ini
