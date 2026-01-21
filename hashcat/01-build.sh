#!/bin/bash

set -e

cp -r --reflink=auto hashcat build

make -C build
