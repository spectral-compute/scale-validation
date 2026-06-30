#!/bin/bash

set -e

ctest --test-dir build/ -parallel 8 --verbose

cd -
