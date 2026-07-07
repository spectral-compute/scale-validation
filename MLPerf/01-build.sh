#!/bin/bash

set -e

cd MLPerf

cd benchmarks/retinanet/implementations/pytorch

docker build -f Dockerfile.x86_64 -t scale-mlperf-retinanet:latest .