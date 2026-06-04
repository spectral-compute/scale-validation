#!/bin/bash

set -e

cd RabbitCT

./rabbitRunner-NVCC \
  -i ./RabbitInput/RabbitInput.rct \
  -m LolaBunny \
  -s 256