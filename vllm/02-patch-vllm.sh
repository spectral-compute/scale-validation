#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Upstream's way to build against an existing torch: drop the torch pins.
cd vllm
python3 tools/use_existing_torch.py
