#!/bin/bash

set -e

cd ds4
make cuda-generic
./download_model.sh q2-imatrix

cd -
