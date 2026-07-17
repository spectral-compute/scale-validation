# Level 5 composite models

These cases join several of the lower-level operations into short model blocks without yet becoming full dataset workloads

Each model starts from a generated state and uses one fixed prepared batch. The cases retain the initial activations, first gradients, parameter checkpoints and evaluation logits around two optimiser updates

- `test_mlp_block.py` combines Linear layers, ReLU, cross-entropy, autograd and AdamW
- `test_cnn_block.py` combines convolution, ReLU, pooling, flattening, Linear layers, cross-entropy, autograd and SGD
- `test_attention_block.py` combines projections, batched matrix multiplication, masking, softmax, residual addition, LayerNorm, pooling, cross-entropy, autograd and AdamW

The run is intentionally short. Level 5 is meant to catch interactions between components while keeping the first divergence fairly easy to locate

The three modules expose their example functions as well as the normal catalogue dispatcher. Level 0 calls those same functions, so the quick demonstrations and Level 5 use the same model setup and optimisation path
