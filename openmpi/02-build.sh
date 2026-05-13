#!/bin/bash

set -e

make -O -C build -sk -j$(nproc) install
