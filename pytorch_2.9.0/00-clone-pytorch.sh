#!/bin/bash

set -e
source "$(dirname "$0")"/../util/git.sh

do_clone pytorch_2.9.0 https://github.com/pytorch/pytorch.git v2.9.0-rc4
