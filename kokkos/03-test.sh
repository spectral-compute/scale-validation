#!/bin/bash

set -e

ctest --test-dir build/ --output-on-failure —parallel 8

cd -
