# Shared case helpers

These files keep repeated setup and output handling out of the actual test cases

- `data.py` loads independent copies of prepared NumPy arrays
- `demo.py` builds the small readable summary used by Level 0 and its CSV
- `dispatch.py` maps catalogue case IDs to their implementation functions
- `tensors.py` handles predictable device and dtype conversion
- `models.py` defines the fixed linear, MLP, CNN, attention and Transformer models used by generated initial states
- `learning.py` loads model state and snapshots parameters, gradients and optimiser internals
- `mixed_precision.py` builds the fixed AMP batch and records GradScaler decisions consistently
- `composite.py` runs the common two-step Level 5 optimisation path and records matching checkpoints for each model
- `workloads.py` runs the fixed Level 6 training and evaluation path, including exact batch rows, full checkpoint logits and optimiser state

Suite-wide choices still belong in `config/suite_config.py`. These helpers should implement behaviour, not invent new policy
