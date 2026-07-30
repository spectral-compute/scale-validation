#!/usr/bin/env bash
set -euo pipefail

source pytorch/.venv/bin/activate

# TODO(#1144): Kill each of these.
#
# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

# Every example trains for this many epochs.
EPOCHS="${EPOCHS:-5}"

# If not writing to a terminal, make sure we still get all the logs despite
# abnormal sudden exit.
export PYTHONUNBUFFERED=1

echo "=== mnist ==="
(
  cd examples/mnist
  python main.py --epochs "$EPOCHS"
)

echo "=== mnist_rnn ==="
(
  cd examples/mnist_rnn
  # Unlike most of the examples, the GPU is opt-in here, not opt-out.
  python main.py --accel --epochs "$EPOCHS"
)

echo "=== mnist_forward_forward ==="
(
  cd examples/mnist_forward_forward
  python main.py --epochs "$EPOCHS"
)

echo "=== siamese_network ==="
(
  cd examples/siamese_network
  python main.py --epochs "$EPOCHS"
)

# Train each language model type on the bundled wikitext-2 corpus, then
# generate text from the model.pt checkpoint that training leaves behind.
for model in RNN_TANH RNN_RELU LSTM GRU Transformer ; do
  echo "=== word_language_model ($model) ==="
  (
    cd examples/word_language_model
    # The GPU is opt-in here too.
    python main.py --accel --model "$model" --epochs "$EPOCHS"
    python generate.py --accel
  )
done
