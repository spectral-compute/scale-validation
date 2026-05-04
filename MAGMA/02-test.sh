#!/bin/bash

set -e

cp MAGMA/testing/run_tests.py build/testing/

cd "build/testing/"
./run_tests.py
