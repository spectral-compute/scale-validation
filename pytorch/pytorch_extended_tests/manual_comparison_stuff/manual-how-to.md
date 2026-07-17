# Running the comparison tools on Linux

This starts from an empty working folder.It only needs Python, numpy, and matplotlib.

## 1. Make working folder

```bash
mkdir -p ~/pytorch-comparisons
cd ~/pytorch-comparisons
```

## 2. Copy the required files from `pytorch_extended_tests`

Copy these two folders without flattening them:

```text
pytorch-comparisons/
├── config/
│   ├── __init__.py
│   ├── suite_config.py
│   └── test_catalogue.py
└── manual_comparison_stuff/
    ├── analyse_repeatability.py
    ├── compare_environment_outputs.py
    ├── compare_repeatability_analyses.py
    ├── comparison_policy.py
    ├── comparison_policy_template.json
    └── level_0_first_look.py
```

Example:

```bash
cp -a /path/to/pytorch_extended_tests/config .
cp -a /path/to/pytorch_extended_tests/manual_comparison_stuff .
```

Keep the folders beside each other. `analyse_repeatability.py` uses `config/test_catalogue.py` to recover the level, category and output metadata.

## 3. Create and activate the virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install numpy matplotlib
```

Check the imports if you want to be sure:

```bash
python -c "import numpy, matplotlib; print('Comparison environment ready')"
```

Reactivate the environment in a later shell with:

```bash
cd ~/pytorch-comparisons
source .venv/bin/activate
```

---

# A. Summary comparison workflow

This compares repeatability-analysis json files rather than loading every raw tensor for the cross-environment comparison.

It is quicker and smaller, but a changed tensor hash may be reported as `MAYBE` because the JSON does not contain the tensor values.
Might be better for nightlies?

## A1. Arrange the raw CI outputs

Create one folder per environment:

```bash
mkdir -p summary_workflow/raw/reference
mkdir -p summary_workflow/raw/a100_gcc
mkdir -p summary_workflow/raw/h100_clang
```

Copy each complete CI output into a run folder whose name starts with `repeatability_`:

```text
summary_workflow/
└── raw/
    ├── reference/
    │   ├── repeatability_001/
    │   ├── repeatability_002/
    │   └── repeatability_003/
    ├── a100_gcc/
    │   ├── repeatability_001/
    │   ├── repeatability_002/
    │   └── repeatability_003/
    └── h100_clang/
        ├── repeatability_001/
        ├── repeatability_002/
        └── repeatability_003/
```

Each `repeatability_*` folder must directly contain the unmodified suite result bundle:

```text
run_manifest.json
observations.jsonl
test_status.json
artifacts/
```

`execution.log`, `level_0_summary.csv` and the other files may remain in the bundle.

Use environment names which identify the GPU and build, for example:

```text
a100_gcc
a100_clang
h100_gcc
cpu_reference
```

Do not combine runs from different environments in the same environment folder.

## A2. Analyse repeatability for the reference

```bash
python manual_comparison_stuff/analyse_repeatability.py \
    summary_workflow/raw/reference \
    --write-populated-policy
```

This writes:

```text
summary_workflow/raw/reference/repeatability_analysis/
├── repeatability_analysis.json
├── repeatability_analysis.md
├── comparison_policy.json
└── *.png
```

## A3. Analyse repeatability for every candidate

```bash
python manual_comparison_stuff/analyse_repeatability.py \
    summary_workflow/raw/a100_gcc

python manual_comparison_stuff/analyse_repeatability.py \
    summary_workflow/raw/h100_clang
```

Repeat this command for each additional environment.

## A4. Collect the analysis JSON files

```bash
mkdir -p summary_workflow/repeatability_outputs

cp \
    summary_workflow/raw/reference/repeatability_analysis/repeatability_analysis.json \
    summary_workflow/repeatability_outputs/reference.json

cp \
    summary_workflow/raw/a100_gcc/repeatability_analysis/repeatability_analysis.json \
    summary_workflow/repeatability_outputs/a100_gcc.json

cp \
    summary_workflow/raw/h100_clang/repeatability_analysis/repeatability_analysis.json \
    summary_workflow/repeatability_outputs/h100_clang.json

cp \
    summary_workflow/raw/reference/repeatability_analysis/comparison_policy.json \
    summary_workflow/repeatability_outputs/comparison_policy.json
```

The reference analysis file must be named exactly:

```text
reference.json
```

The other JSON filenames become the candidate names in the report.

The resulting structure should be:

```text
summary_workflow/
└── repeatability_outputs/
    ├── reference.json
    ├── scale-gfx1100.json
    ├── scale-gfx1201.json
    └── comparison_policy.json
```

## A5. Compare the repeatability analyses

```bash
python manual_comparison_stuff/compare_repeatability_analyses.py \
    summary_workflow/repeatability_outputs \
    --policy summary_workflow/repeatability_outputs/comparison_policy.json
```

Outputs:

```text
summary_workflow/repeatability_outputs/repeatability_comparison/
├── repeatability_comparison_results.json
├── repeatability_comparison_results.md
└── repeatability_comparison_status.png
```

Open the Markdown report with, for example:

```bash
less summary_workflow/repeatability_outputs/repeatability_comparison/repeatability_comparison_results.md
```

## A6. Optional Level 0 CSV first look

Use one `level_0_summary.csv` per environment:

```bash
mkdir -p level_0_summaries

cp /path/to/reference_run/level_0_summary.csv level_0_summaries/reference.csv
cp /path/to/a100_gcc_run/level_0_summary.csv level_0_summaries/a100_gcc.csv
cp /path/to/h100_clang_run/level_0_summary.csv level_0_summaries/h100_clang.csv
```

Run:

```bash
python manual_comparison_stuff/level_0_first_look.py level_0_summaries
```

Outputs:

```text
level_0_summaries/
├── level_0_first_look_collated.md
└── level_0_first_look_summary.md
```

This is deliberately rough. Use the detailed workflow for the real tensor comparison.

---

# B. Detailed comparison workflow

This compares the raw scalar values and tensor artefacts from every candidate run against every reference run.

It also analyses repeatability for every environment and populates the comparison policy from the reference runs.

## B1. Create the comparison root

```bash
mkdir -p detailed_comparison/reference
mkdir -p detailed_comparison/a100_gcc
mkdir -p detailed_comparison/h100_clang
```

Copy the policy template:

```bash
cp \
    manual_comparison_stuff/comparison_policy_template.json \
    detailed_comparison/comparison_policy_template.json
```

## B2. Copy the raw CI outputs

The reference environment folder must be named:

```text
reference
```

Candidate environment folders can use any clear name.

Run-folder names are unimportant in this workflow. Use a consistent convention such as `run_001`.

```text
detailed_comparison/
├── comparison_policy_template.json
├── reference/
│   ├── run_001/
│   ├── run_002/
│   └── run_003/
├── scale-gfx1100/
│   ├── run_001/
│   ├── run_002/
│   └── run_003/
└── scale-gfx1201/
    ├── run_001/
    ├── run_002/
    └── run_003/
```

Each run folder must directly contain:

```text
run_manifest.json
observations.jsonl
test_status.json
artifacts/
```

Do not copy only `level_0_summary.csv`. The detailed comparison needs the complete result bundle.

## B3. Run the detailed comparison

```bash
python manual_comparison_stuff/compare_environment_outputs.py \
    detailed_comparison
```

The script will:

- analyse repeatability within `reference`
- analyse repeatability within each candidate environment
- populate the policy from the reference repeatability
- compare every candidate run with every reference run
- verify tensor artefact hashes
- apply the populated exact and numerical policies
- write JSON, Markdown and Matplotlib reports

Outputs:

```text
detailed_comparison/
├── comparison_policy.json
└── comparison_results/
    ├── comparison_results.json
    ├── comparison_results.md
    ├── environment_status_counts.png
    └── environment_worst_tolerance_ratio.png
```

Open the report:

```bash
less detailed_comparison/comparison_results/comparison_results.md
```

## B4. Useful optional flags

Keep every individual reference/candidate pair in the JSON:

```bash
python manual_comparison_stuff/compare_environment_outputs.py \
    detailed_comparison \
    --retain-all-pairs
```

Skip plots:

```bash
python manual_comparison_stuff/compare_environment_outputs.py \
    detailed_comparison \
    --no-plots
```

Use a different reference-folder name:

```bash
python manual_comparison_stuff/compare_environment_outputs.py \
    detailed_comparison \
    --reference-folder known_good_gpu
```

Normally, keeping the folder name `reference` is simpler.

---

# Multiple precision profiles

Multiple precision profiles can be included in the same runs.

For example, every CUDA environment may contain:

```text
controlled_fp32
amp_fp16
```

The tools handle this as follows:

- `profile_id` is part of every output identity
- FP32 outputs are compared only with FP32 outputs
- AMP FP16 outputs are compared only with AMP FP16 outputs
- repeatability is measured separately for each profile
- the generated policy contains separate calibrated output entries for each profile
- the Markdown and JSON reports retain the profile name

Requirements:

- every repeat within one environment must use the same profile list
- the reference and all candidate environments must use the same profile list
- use the same profile order as well
- use the same levels, cases, seed, catalogue version and prepared datasets
- `controlled_fp16` and `amp_fp16` are different profiles and are not interchangeable

A profile-set mismatch is treated as incompatible metadata and makes the environment comparison fail.

E.g.:

- CPU versus GPU: run both with `controlled_fp32` only
- known-good combo versus other compiler-GPU-combos: run all environments with `controlled_fp32 amp_fp16`
- BF16 comparison: opt every compared GPU into the same BF16 profile
- if two environments do not support the same profiles, run separate comparison roots containing only their shared profile set