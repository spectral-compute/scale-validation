#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

ctest --test-dir build
