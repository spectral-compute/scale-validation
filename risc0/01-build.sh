#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

(cd "risc0" &&
    cargo install --force --path risc0/cargo-risczero &&
    cargo risczero install)
