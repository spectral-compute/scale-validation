#!/bin/bash

set -e

cd RabbitCT

./rabbitRunner-NVCC \
  -i ./RabbitInput/RabbitInput.rct \
  -m LolaCUDA \
  -s 1024 \
  -c ./RabbitInput/Reference1024.vol
