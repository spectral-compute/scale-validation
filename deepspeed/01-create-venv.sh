#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/pytorch-venv.sh

create_pytorch_venv
