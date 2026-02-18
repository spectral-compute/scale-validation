#!/bin/bash

set -ETeuo pipefail

./install/bin/llama-bench -m "models/llama-2-7b.Q4_0.gguf"
