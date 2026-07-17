# Level 0 quick workloads

This is the first thing I expect people to run when checking a new build or showing the suite to someone

It trains and evaluates four small classifiers using the fixed generated model inputs:

- a linear classifier
- the Level 5 MLP
- the Level 5 CNN
- the Level 5 residual multi-head attention classifier

The MLP, CNN and attention examples call the same execution functions as Level 5. This keeps the quick demonstration representative rather than maintaining a second cut-down implementation

The ordinary detailed tensor artefacts are still saved. The suite also writes `level_0_summary.csv` at the top of the result bundle so there is a quick human-readable view of the initial and final losses, predictions, logits, gradients and parameter norms
