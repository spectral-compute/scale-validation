# Level 6 real workloads

These cases run short but complete training jobs on the three prepared datasets

They are deliberately step-limited rather than accuracy benchmarks. The point is to exercise a realistic chain of data loading, forward passes, losses, backward passes, optimiser updates and full evaluation while keeping the output small enough to compare between CI jobs

Each workload records:

- the exact source rows used by every training batch
- full evaluation logits before training and at each configured checkpoint
- training loss at every optimiser step
- checkpoint loss and accuracy values
- all gradients from the first backward pass
- the early parameter states
- optimiser and gradient-scaler state at checkpoints
- final parameters, predictions and task metrics

The downloaded source datasets must be prepared with `datasets/generate_datasets.py` before this level can run
