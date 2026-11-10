#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd llm.c

# Upstream's test: compares logits, loss and gradients with PyTorch's reference state.
./test_gpt2fp32cu | tee test.log
grep -q "^overall okay: 1$" test.log

# The sampled text after training depends on rounding (it differs between NVIDIA GPUs), so
# training is only run to completion.
./train_gpt2fp32cu
