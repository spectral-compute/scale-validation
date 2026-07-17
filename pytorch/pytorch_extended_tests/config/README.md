# Configuration

The suite uses Python configuration rather than machine-specific YAML files. 
They are a bit more readable.

## Files

- `suite_config.py` contains suite-wide execution, seed, dataset, model, precision, AMP and workload choices
- `test_catalogue.py` contains stable test, case and output IDs
- `__init__.py` exposes the small set of version and seed values used by other packages

`test_catalogue.py` deliberately contains no numerical tolerances. CI records raw outputs only. Comparison policies will be introduced with the separate comparison harness

## Device selection

The default device is CUDA. Set this environment variable for the CPU reference job:

```bash
export PYTORCH_EXTENDED_TESTS_DEVICE=cpu
```

The Python orchestrator validates the value against `ALLOWED_DEVICES`

## Seeds

`ROOT_SEED` is the only manually selected seed. Code which needs a distinct random stream should call:

```python
from config.suite_config import derive_seed

seed = derive_seed("workloads.tabular_classification", "training_order")
```

Do not use Python's built-in `hash()` to derive seeds because its output can vary between processes

## Changing configuration

Changing generated dataset settings requires regenerating and recommitting the prepared datasets and `dataset_manifest.json`

Changes which alter result meaning should also update the relevant version string. For the first implementation these are all `v1`

## Default profiles by device

CUDA jobs run `controlled_fp32` and `amp_fp16` by default. This gives an ordinary FP32 baseline and the usual mixed-precision FP16 training path without paying for every optional precision mode in the first CI pass

CPU jobs run `controlled_fp32` by default. Raw FP16 is deliberately CUDA-only in this suite

FP64, raw FP16, raw BF16 and BF16 autocast remain available as explicit opt-ins:

```bash
PYTHONPATH=src:. python -m pytorch_extended_tests.orchestrator.run_suite \
    --profiles controlled_fp32 amp_fp16 amp_bfloat16 controlled_fp64
```

## Child-process environment

`SUBPROCESS_ENVIRONMENT` fixes Python hashing, deterministic CUDA BLAS workspace behaviour and the main CPU thread-count environment variables before each isolated test process starts. These values should normally remain unchanged within a suite version

## Implemented and enabled levels

All seven levels are implemented:

- `level_0_smoke_workloads`
- `level_1_core_tensor`
- `level_2_numerical_kernels`
- `level_3_autograd_and_learning`
- `level_4_precision_and_execution`
- `level_5_composite_models`
- `level_6_real_workloads`

`EXECUTION["enabled_levels"]` contains Level 0 only by default. The quick run needs only `model_inputs_v1`, so it does not depend on the external Level 6 datasets

## Level 3 settings

`LEVEL_3_TESTS` keeps the embedding shape, normalisation settings and optimiser variants in one place

The individual case files should not add their own learning rates, optimiser betas or other suite-wide constants

## Level 4 settings

`PRECISION_MODE_CASES` defines the strict, high and medium float32 modes

`LEVEL_4_TESTS` holds the AMP learning rate, GradScaler values and serialisation checkpoint settings. The mixed-precision and save/load cases should not add separate local values.

## Level 5 settings

`BLOCK_TESTS` contains the short composite-model training length, checkpoint steps and optimiser choices. The MLP and attention block use AdamW, while the CNN uses SGD, so the level covers both optimiser paths without adding more nearly identical cases

## Level 6 settings

`WORKLOADS` contains the dataset, optimiser, batch-size, training-length and checkpoint choices for each real workload

`WORKLOAD_CAPTURE` defines which early parameter states are retained. The workload helper derives the exact shuffled batch order from the root seed and records the source indices used at every step.

## Level 0 settings

`LEVEL_0_DEMOS` holds the CSV filename, prediction preview length and the linear example's optimiser settings

The MLP, CNN and attention examples deliberately reuse `BLOCK_TESTS` and the public Level 5 execution functions. This means the quick demonstrations and the detailed composite tests use the same calculations. 
