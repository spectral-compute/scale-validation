#!/bin/bash

set -e

make -C build -sk -j$(nproc) install
