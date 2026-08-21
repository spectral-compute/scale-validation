#!/usr/bin/env bash

set -e

make -O -C build -sk -j"$(nproc)" install
