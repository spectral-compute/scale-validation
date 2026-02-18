#!/bin/bash

set -e

cd "risc0"

cargo install --force --path risc0/cargo-risczero
cargo risczero install

cd -
