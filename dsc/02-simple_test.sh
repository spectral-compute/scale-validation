#!/bin/bash

source "$(dirname "$0")"/../util/args.sh "$@"
cd "$OUT_DIR/dsc"

python3 -m venv venv
source venv/bin/activate
python3 -m pip install -e .
python3 -m pip install -r ./requirements.txt

python3 -c "import dsc; x = dsc.arange(10, device='cuda'); print(x)"
