#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Test setup fixtures run `python3` from PATH.
PATH="$(realpath venv/bin):${PATH}"

ctest --test-dir build --output-on-failure
