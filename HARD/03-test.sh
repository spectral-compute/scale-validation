#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The verification tests run tools/*.py with `python3` from PATH.
PATH="$(realpath venv/bin):${PATH}"

ctest --test-dir build --output-on-failure
