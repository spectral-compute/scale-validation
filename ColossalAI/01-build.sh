#!/bin/bash

set -e

cd ColossalAI

python3 -m venv venv
source venv/bin/activate

BUILD_EXT=1 pip install .
