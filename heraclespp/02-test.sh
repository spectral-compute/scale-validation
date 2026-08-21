#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

./build/src/nova++ ./heraclespp/inputs/rayleigh_taylor3d.ini
