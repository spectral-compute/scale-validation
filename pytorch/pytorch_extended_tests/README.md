# pytorch_extended_tests

A set of really extended PyTorch numerical tests which to run against different compiler and GPU builds

The CI job runs the cases and saves raw outputs. It does not decide whether one build matches another. 
For now, please somebody manually retrieve the CI artifacts and run the repeatability and cross-environment comparisons separately with the scripts in `manual_comparison_stuff/`

That can be automated as well in future and put in CI somewhere, but doesn't fit into the way CI runs the scale validation repo. Should save reference standards somewhere, once there's enough accumulated.

## Why the suite is split into levels

The levels move from small, hopefully-easy-to-diagnose stuff towards longer pieces of work. If a training workload differs, looking back through the lower levels should help work out whether the first disagreement was in a basic tensor operation, a numerical kernel, autograd, mixed precision or the combined model itself
Examples different = bad. Look at lower levels to see where/why. Hopefully.

- Level 0 runs four quick training and inference demonstrations: a linear classifier, MLP, CNN and attention model
- Level 1 does core tensor creation, arithmetic, mathematical functions, indexing, shape operations and type promotion
- Level 2 does reductions, matrix multiplication, convolution, pooling, linear solves, matrix factorisations, eigensystems, FFTs and special functions
- Level 3 does autograd graphs, neural-network layers, normalisation, attention, losses and optimiser updates
- Level 4 does float32 backend precision modes, FP16 and BF16 autocast, gradient scaling and serialisation round trips
- Level 5 combines the lower-level operations into short MLP, CNN and attention blocks with fixed optimiser updates
- Level 6 runs small tabular, image and text training workloads with fixed datasets and initial states


## How to use it

For the default Level 0 run, generate the fixed model inputs once:

```bash
python datasets/generate_datasets.py --only generated
```

Commit the generated `datasets/prepared/` files and the updated `datasets/dataset_manifest.json`. 

I want CI to only consume those prepared files, not regenerate data. Just in case that's a source of differences. But these should get moved to somewhere that CI can read from eventually, not stay in the scale validation repo xxx

Level 0 does not need the externally downloaded datasets. 
But we do need to download and prepare those from `datasets/README.md` before enabling Level 6

The normal CI entry point runs Level 0 only. Once that looks sensible, enable the other levels. This example runs the complete suite:

```bash
cd ..
./run_pytorch_extended_tests.sh \
    --levels \
    level_0_smoke_workloads \
    level_1_core_tensor \
    level_2_numerical_kernels \
    level_3_autograd_and_learning \
    level_4_precision_and_execution \
    level_5_composite_models \
    level_6_real_workloads
```

Check the selected environment before running the suite:

```bash
python tools/validate_setup.py
```

For the CPU reference job:

```bash
python tools/validate_setup.py --device cpu
```

Run the normal CI entry point with:

```bash
cd ..
./run_pytorch_extended_tests.sh
```

The script activates `pytorch/.venv`. Set `PYTHON` only when that environment needs a non-default interpreter command:

```bash
cd ..
PYTHON=/path/to/python ./run_pytorch_extended_tests.sh
```

Set the CPU reference device with:

```bash
cd ..
PYTORCH_EXTENDED_TESTS_DEVICE=cpu ./run_pytorch_extended_tests.sh
```

The shell script passes extra arguments to the Python orchestrator. For example, this runs only Level 4 FP32 cases on CPU:

```bash
cd ..
PYTORCH_EXTENDED_TESTS_DEVICE=cpu \
    ./run_pytorch_extended_tests.sh \
    --levels level_4_precision_and_execution \
    --profiles controlled_fp32
```

The Linux CI wrapper writes the complete raw bundle to:

```text
/tmp/ci_benchmarks/pytorch
```

Check a completed result bundle with:

```bash
python tools/inspect_result_bundle.py /tmp/ci_benchmarks/pytorch
```

To analyse repeatability, collect unmodified result bundles from repeated runs of the same environment beneath one directory. Each bundle directory must begin with `repeatability_`:

```text
collected_runs/
├── repeatability_run_001/
├── repeatability_run_002/
└── repeatability_run_003/
```

Then run:

```bash
python manual_comparison_stuff/analyse_repeatability.py collected_runs
```

This writes an overly detailed json file, a markdown report and graphs in `collected_runs/repeatability_analysis/`. Add `--write-populated-policy` when the runs are from the reference environment and the analyser will also fill the central policy template from the observed reference variability.

To compare portable repeatability JSON files, put `reference.json` and the candidate json files in `repeatability_outputs/` and run `manual_comparison_stuff/compare_repeatability_analyses.py`. To perform the actual tensor-level GPU comparison, use `manual_comparison_stuff/compare_environment_outputs.py` with a `reference/` folder and one folder per compiler-GPU combo.

## Precision profiles

The names are slightly PyTorch-specific, but the basic idea is:

- **FP32** is normal 32-bit floating point. The main baseline, because it has a hopefully sensible balance of speed, range and precision
- **FP16** is 16-bit floating point. It is faster and smaller on suitable GPUs, but has a much narrower numerical range and is easier to overflow or underflow
- **AMP** means Automatic Mixed Precision. PyTorch runs suitable operations in a lower precision while keeping numerically sensitive work and the main model state in FP32. AMP FP16 normally also uses gradient scaling to protect small gradients
- **BF16** is another 16-bit format. It has less precision than FP32 but a much wider range than FP16, so is apparently often easier to train with on newer hardware
- **FP64** is 64-bit floating point. It is mainly useful here as a high-precision diagnostic rather than a normal deep-learning setting...
- A `controlled_...` profile moves the inputs and model parameters themselves to that dtype and applies the suite's deterministic settings. An `amp_...` profile keeps the main state in FP32 and uses autocast for eligible operations

I'd use FP32 and AMP FP16 only on CUDA for CI for now. That is the default in the config for now. FP32 gives the clearest baseline, while AMP FP16 tests the lower-precision path most likely to be used for normal GPU training without converting the model parameters themselves to raw FP16

The default profiles are:

- CUDA: `controlled_fp32` and `amp_fp16`
- CPU: `controlled_fp32`

`amp_fp16` keeps the model and optimiser state in FP32, runs eligible forward operations under FP16 autocast, and uses gradient scaling. This is a better initial test than `controlled_fp16`, which moves model parameters themselves to FP16 and is more likely to fail because of range or operator-support limitations

The other profiles remain available as explicit opt-ins:

- `controlled_fp64`: useful as a higher-precision diagnostic where the operation supports it
- `controlled_fp16`: raw FP16 tensors and model parameters on CUDA
- `controlled_bfloat16`: raw BF16 tensors and model parameters
- `amp_bfloat16`: FP32 model parameters with BF16 autocast

For example, this adds BF16 autocast and FP64 to a CUDA run:

```bash
cd ..
./run_pytorch_extended_tests.sh \
    --profiles controlled_fp32 amp_fp16 amp_bfloat16 controlled_fp64
```

Do not add FP16 to the CPU reference job. CPU runs use FP32 by default; BF16 autocast can be enabled separately where the CPU and PyTorch build support it

## Current scope and CUDA backend notes

Currently tests one CPU or one GPU process at a time. It does **not** test multi-GPU stuff. 

Sparse tensors store only the non-zero parts of data which is mostly zero, using formats such as COO or CSR. They have their own storage invariants, operator coverage, autograd behaviour and CUDA kernels. I have left them out for now because the current suite is deliberately a dense-tensor baseline; adding a few sparse operations would probably just give an illusion of coverage without testing the important format and coalescing cases properly. Sparse support should be added later as a distinct category rather than mixed into the dense tests...

Most CUDA maths in the suite will dispatch through the backend PyTorch selects, for example cuBLAS or cuBLASLt for matrix multiplication and cuFFT for FFTs. The repository tree marks test files containing cases which would normally use **cuDNN** on CUDA when cuDNN is available. Because no cuDNN yet. The marker does not mean that every case in that file uses cuDNN. 

The suite does not require `torch.backends.cudnn.is_available()` to be true. If PyTorch was built without cuDNN, convolution or normalisation operations will use a native CUDA implementation where PyTorch provides one. These paths can be slower and can produce different numerical results from cuDNN, which is useful to observe but means reference and candidate environments should have matching cuDNN availability when the aim is a like-for-like comparison. If a particular operation, dtype or shape has no fallback, the case fails and the exception is retained in the result bundle; it is not silently skipped. Maybe we should disable it for all of them for now actually rather than assuming that the installs mirror SCALE? Does our CUDA install have any packages that we don't do?



## Repository layout

```text
pytorch_extended_tests/
├── README.md
├── manual_comparison_stuff/
│   ├── README.md
│   ├── analyse_repeatability.py
│   ├── compare_environment_outputs.py
│   ├── compare_repeatability_analyses.py
│   ├── comparison_policy.py
│   ├── comparison_policy_template.json
│   └── level_0_first_look.py
├── cases/
│   ├── README.md
│   ├── common/
│   │   ├── README.md
│   │   ├── data.py
│   │   ├── demo.py
│   │   ├── dispatch.py
│   │   ├── learning.py
│   │   ├── mixed_precision.py
│   │   ├── models.py
│   │   ├── tensors.py
│   │   └── workloads.py
│   ├── level_0_smoke_workloads/
│   │   ├── README.md
│   │   └── test_demo_workloads.py              [cuDNN: CNN case]
│   ├── level_1_core_tensor/
│   │   ├── test_tensor_creation_and_dtypes.py
│   │   ├── test_elementwise_arithmetic.py
│   │   ├── test_transcendental_functions.py
│   │   ├── test_indexing_and_shape.py
│   │   └── test_type_promotion.py
│   ├── level_2_numerical_kernels/
│   │   ├── test_reductions_and_statistics.py
│   │   ├── test_matrix_multiplication.py
│   │   ├── test_convolution.py                 [cuDNN]
│   │   ├── test_pooling.py
│   │   ├── test_linear_solve.py
│   │   ├── test_factorisations.py
│   │   ├── test_eigensystems.py
│   │   ├── test_fft.py
│   │   └── test_special_functions.py
│   ├── level_3_autograd_and_learning/
│   │   ├── test_autograd_elementwise.py
│   │   ├── test_autograd_matrix_ops.py         [cuDNN: convolution case]
│   │   ├── test_nn_linear_and_conv.py          [cuDNN: convolution cases]
│   │   ├── test_normalisation.py               [cuDNN: BatchNorm cases where supported]
│   │   ├── test_attention.py
│   │   ├── test_losses.py
│   │   ├── test_optimizer_sgd.py
│   │   └── test_optimizer_adamw.py
│   ├── level_4_precision_and_execution/
│   │   ├── README.md
│   │   ├── test_fp32_precision_modes.py        [cuDNN: convolution case]
│   │   ├── test_amp_fp16.py
│   │   ├── test_amp_bfloat16.py
│   │   └── test_serialisation_roundtrip.py
│   ├── level_5_composite_models/
│   │   ├── README.md
│   │   ├── test_mlp_block.py
│   │   ├── test_cnn_block.py                   [cuDNN]
│   │   └── test_attention_block.py
│   └── level_6_real_workloads/
│       ├── README.md
│       ├── test_tabular_training_workload.py
│       ├── test_cnn_training_workload.py       [cuDNN]
│       └── test_transformer_training_workload.py
├── ci/
│   └── run_pytorch_extended_tests.ps1
├── config/
│   ├── README.md
│   ├── suite_config.py
│   └── test_catalogue.py
├── datasets/
│   ├── README.md
│   ├── dataset_manifest.json
│   ├── generate_datasets.py
│   ├── downloaded/
│   └── prepared/
├── src/
│   └── pytorch_extended_tests/
│       ├── case_api.py
│       ├── precision_settings.py
│       ├── datasets/
│       │   └── validation.py
│       ├── orchestrator/
│       │   ├── execution_plan.py
│       │   ├── run_suite.py
│       │   ├── run_test_file.py
│       │   └── subprocess_runner.py
│       └── results/
│           ├── artifact_writer.py
│           ├── level_0_summary.py
│           ├── observation.py
│           ├── result_bundle.py
│           └── tensor_storage.py
└── tools/
    ├── README.md
    ├── inspect_result_bundle.py
    └── validate_setup.py
```

Generated and downloaded dataset files are not all shown in the tree because that would make it fairly unreadable

## What the non-level files are for

- `README.md`: the main entry point for the repository
  This file =)

- `../run_pytorch_extended_tests.sh`: the Linux CI wrapper
  It clears the fixed result directory, launches the Python orchestrator and keeps a combined execution log
  The orchestrator performs configuration and dataset preflight checks before starting case processes

- `manual_comparison_stuff/`: the manual repeatability and comparison harness
  It is the only copy of these scripts in the repository; CI does not import or run them

- `config/suite_config.py`: the central place for suite-wide choices
  It holds the root seed, profiles, precision controls, timeouts, model sizes, optimiser settings and the enabled levels so these decisions are not copied into individual cases

- `config/test_catalogue.py`: the stable map of test IDs, case IDs and output IDs
  The orchestrator uses it to plan work and the manual comparison harness uses the same names to line up outputs from different builds

- `config/README.md`: notes on changing central configuration
  It calls out which changes require data regeneration or a version update and documents the environment-variable overrides

- `datasets/generate_datasets.py`: the one manual data-generation and preprocessing script
  It generates canonical numerical inputs, fixed model states and prepared versions of the downloaded datasets from the root seed

- `datasets/dataset_manifest.json`: the record of dataset sources and generated files
  It stores URLs, checksums, shapes and preprocessing metadata so CI can prove that each build used the same inputs

- `datasets/README.md`: the dataset setup guide
  It lists the download links, expected filenames, licences and the one-off preparation command

- `cases/README.md`: the case-writing contract
  It explains that case files produce raw named observations and must not contain comparison tolerances

- `cases/common/data.py`: the prepared-array loader
  It returns independent NumPy copies so an in-place test cannot modify the input seen by the next case

- `cases/common/dispatch.py`: the small case-ID dispatcher
  It keeps each test module's public `run_case` function consistent and gives a clear error for an unimplemented catalogue case

- `cases/common/demo.py`: the small Level 0 summary builder
  It turns the detailed block outputs into a few readable losses, predictions, logit statistics, activation statistics, gradient norms and parameter norms

- `cases/common/tensors.py`: tensor conversion and structure helpers
  It handles device and dtype conversion in one place and keeps complex and non-contiguous cases predictable

- `cases/common/models.py`: the fixed shared model definitions
  The parameter names match the generated initial-state files, which lets different builds start from exactly the same values

- `cases/common/learning.py`: model, gradient and optimiser-state helpers
  It snapshots named tensors in a stable way so training-related cases retain enough detail to locate the first divergence

- `cases/common/mixed_precision.py`: the shared AMP and GradScaler helpers
  It keeps scaler construction and step-skipping records consistent between the mixed-precision and composite-model cases

- `cases/common/composite.py`: the shared short-training loop for Levels 0 and 5
  It records the same initial forward pass, first gradients, parameter checkpoints and evaluation outputs for each composite model

- `cases/common/workloads.py`: the shared Level 6 training and evaluation loop
  It fixes the batch order from the root seed and records the same losses, gradients, checkpoints, optimiser state and final metrics for all three real workloads

- `src/pytorch_extended_tests/case_api.py`: the public interface passed to case modules
  It exposes the selected profile, device, seed, temporary directory, prepared dataset paths and the output recorder protocol

- `src/pytorch_extended_tests/precision_settings.py`: the compatibility layer for float32 precision controls
  It avoids mixing old and new PyTorch TF32 APIs while still supporting older builds where cuDNN only exposes the legacy flag

- `src/pytorch_extended_tests/datasets/validation.py`: the CI dataset preflight
  It verifies required prepared files and checksums before any test process starts, so missing or stale inputs fail clearly

- `src/pytorch_extended_tests/orchestrator/execution_plan.py`: the ordered task planner
  It combines selected levels, tests, profiles and device into isolated test-module/profile tasks

- `src/pytorch_extended_tests/orchestrator/run_suite.py`: the main Python suite runner
  It validates data, runs the task plan, gathers statuses and finalises the raw result bundle

- `src/pytorch_extended_tests/orchestrator/run_test_file.py`: the child-process entry point
  It applies the profile, seeds the process, imports one test module and checks that every required output was produced

- `src/pytorch_extended_tests/orchestrator/subprocess_runner.py`: the process-isolation wrapper
  It sets the deterministic child environment, captures logs and protects the rest of the run from timeouts or CUDA failures in one module

- `src/pytorch_extended_tests/results/level_0_summary.py`: the Level 0 CSV writer
  It collects the required summary observation from each quick example and writes one row per example and precision profile

- `src/pytorch_extended_tests/results/observation.py`: the JSON record model
  It defines the stable machine-readable shape used for case statuses and named outputs

- `src/pytorch_extended_tests/results/tensor_storage.py`: the lossless tensor binary format
  It stores dtype, shape and raw bytes without silently converting lower-precision, complex or integer tensors

- `src/pytorch_extended_tests/results/artifact_writer.py`: the observation and artifact writer
  It validates output kinds, writes tensors into the artifact tree and records checksums and paths in JSONL

- `src/pytorch_extended_tests/results/result_bundle.py`: the top-level bundle finaliser
  It writes the manifest, merges task observations and creates the final execution summary even when some tasks fail

- `tools/validate_setup.py`: the local and CI preflight command
  It checks configuration, catalogue entries, datasets, selected profiles, PyTorch import, device availability and case-module imports

- `manual_comparison_stuff/analyse_repeatability.py`: the repeated-run analysis tool
  It measures within-environment variation, writes JSON/Markdown/graphs and can populate a central policy from the reference runs

- `manual_comparison_stuff/comparison_policy_template.json`: the central comparison-policy starting point
  It contains exact-match rules, static numerical floors and hard ceilings; reference repeatability fills the per-output limits

- `manual_comparison_stuff/comparison_policy.py`: the shared policy calibration and judgement code
  The manual comparison scripts use this module so policy population and PASS/MAYBE/FAIL decisions stay consistent

- `manual_comparison_stuff/compare_repeatability_analyses.py`: the portable repeatability-summary comparator
  It compares `reference.json` with other repeatability-analysis JSON files but cannot measure changed tensor values without the raw artefacts

- `manual_comparison_stuff/compare_environment_outputs.py`: the full raw-output comparator
  It calibrates the policy from `reference/`, checks each environment's repeatability and compares candidate runs with the reference tensor by tensor

- `manual_comparison_stuff/level_0_first_look.py`: the rough manual Level 0 comparison script
  It collates summary CSV files and gives a deliberately coarse PASS, FAIL or MAYBE result against `reference.csv`

- `tools/inspect_result_bundle.py`: the completed-bundle checker
  It parses the JSON files, verifies every tensor artifact and flags missing, corrupt or unreferenced files before results are archived

- `tools/README.md`: quick notes for the maintenance tools
  It gives the normal commands without making the root README even longer

- `.gitignore`: exclusions for local Python and editor noise
  Prepared test inputs are intentionally not ignored because they are part of the fixed inputs used by CI

- `__init__.py` files: package markers and small public re-exports
  They keep imports predictable without containing suite policy or test behaviour

## Result files

A successful Linux or CI invocation writes:

```text
/tmp/ci_benchmarks/pytorch/
├── run_manifest.json
├── test_catalogue.json
├── test_status.json
├── observations.jsonl
├── level_0_summary.csv
├── execution.log
└── artifacts/
```


The tensor values are stored as lossless binary artifacts. `observations.jsonl` contains their dtypes, shapes, checksums and relative paths

`level_0_summary.csv` is written whenever Level 0 is selected. It is only a convenient first look; the detailed artefacts should be the gold standard comparison source of truth

## Configuration notes

Everything that is expected to stay consistent between builds should be centralised in `config/suite_config.py`. This includes the seed, backend profiles, AMP scaler settings, model dimensions, optimiser values and checkpoint choices

Stable test, case and output IDs live in `config/test_catalogue.py`

Numerical tolerances live in `manual_comparison_stuff/comparison_policy_template.json` and are populated from the reference repeatability analysis. 

