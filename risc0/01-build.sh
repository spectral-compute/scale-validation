#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

(cd "risc0" &&
    cargo install --force --path risc0/cargo-risczero &&
    cargo risczero install)
