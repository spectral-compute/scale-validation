# Manual comparison tools

These scripts are for after CI has finished a few times and someone copied the raw result folders to their local.

CI does not import or run these files

The detailed comparisons work at output-leaf level (leaf = one final scalar, exact value or tensor reached after recursively flattening a stored output). This means a model state can be checked parameter by parameter rather than being reduced to one result.

note - on training, it's steps rater than epochs, to make things not take so long. If everything looks good, we can increase it (maybe not run every night?).

## Files

- `level_0_first_look.py`: quick comparison of the small Level 0 CSV summaries
  - Input: a `level_0_summaries/` folder containing `reference.csv` and one CSV per candidate environment
  - Output: `level_0_first_look_collated.md` and `level_0_first_look_summary.md` in the input folder
  - This is deliberately rough and does not replace the tensor comparison

- `analyse_repeatability.py`: checks several runs from one environment against each other
  - Input: a folder containing at least two `repeatability_*` subfolders, each an unmodified raw suite result bundle
  - Output: `repeatability_analysis/repeatability_analysis.json`, a Markdown report and some PNG graphs
  - Add `--write-populated-policy` for reference runs to also write `comparison_policy.json`

- `comparison_policy_template.json`: central comparison-policy template
  - Contains the exact-match rules, dtype-specific numerical floors and hard ceilings
  - Reference repeatability fills the per-output and per-leaf calibration entries without replacing hardcoded values

- `comparison_policy.py`: shared policy code
  - Used by the repeatability analyser and both comparison scripts
  - Handles policy loading, calibration, policy lookup and PASS/MAYBE/FAIL/NA judgements

- `compare_repeatability_analyses.py`: compares already-created repeatability JSON files
  - Input: `repeatability_outputs/reference.json` plus one or more candidate JSON files in the same folder
  - Output: `repeatability_outputs/repeatability_comparison/` containing JSON, Markdown and an optional PNG summary
  - It plots representative model losses and sampled final logits, plus Level 6 evaluation loss/accuracy
  - A changed tensor hash is normally MAYBE here because the raw tensor values are not in the analysis JSON

- `compare_environment_outputs.py`: full raw tensor-level comparison against the reference environment
  - Input: one root folder containing `reference/` and one folder per candidate environment
  - Each environment folder contains one or more raw suite result-bundle subfolders; their names do not matter
  - Output: a populated `comparison_policy.json` plus `comparison_results/` containing JSON, Markdown and optional PNG graphs
  - This is the main comparison when I need an actual numerical judgement

## Repeatability input

```text
collected_runs/
├── repeatability_run_001/
├── repeatability_run_002/
└── repeatability_run_003/
```

```bash
python manual_comparison_stuff/analyse_repeatability.py collected_runs --write-populated-policy
```

## Repeatability-JSON comparison input

```text
repeatability_outputs/
├── reference.json
├── gfx1201_scale_fp32.json
└── gfx_1100_scale_fp32.json
```

```bash
python manual_comparison_stuff/compare_repeatability_analyses.py repeatability_outputs \
    --policy manual_comparison_stuff/comparison_policy.json
```

## Raw environment comparison input

```text
comparison_root/
├── comparison_policy_template.json
├── reference/
│   ├── run_001/
│   └── run_002/
├── gfx1201_scale_fp32/
│   ├── run_001/
│   └── run_002/
└── gfx_1100_scale_fp32/
    ├── run_001/
    └── run_002/
```

```bash
python manual_comparison_stuff/compare_environment_outputs.py comparison_root
```

The reference and candidate runs should use the same suite version, seed, prepared datasets, levels and profiles. A comparison across deliberately different profile sets will normally be NA or fail the compatibility checks



## Training and inference graphs

- Level 0 and Level 5 use two short optimisation steps
- The current Level 6 workloads are step-limited rather than epoch-limited
- The reports therefore show the first five configured evaluation checkpoints, with the real optimisation-step numbers on the x-axis
- They also show training loss over the first configured number of optimisation steps
- The detailed comparison reads the full final `checkpoint_logits` artefacts
- The summary comparison uses a deterministic compact preview stored in each repeatability-analysis JSON
- True five-epoch plots would require changing the Level 6 workload duration, especially for Fashion-MNIST and the Transformer

Graph limits can be changed in the `reporting` section of `comparison_policy_template.json` without changing the tests

## Reading the graphs

- Every graph includes a title, axis labels and a short explanation on the image
- Reference training curves are labelled `reference baseline`
- Shaded bands on detailed training graphs are the minimum-to-maximum range across repeat runs
- Final-logit scatter plots use the reference on the x-axis and candidates on the y-axis
- The dashed `y = x` line in a logit scatter is exact agreement
- Final-logit error plots show candidate error from the reference and include a labelled zero-error reference baseline
- Prediction-disagreement plots include the reference self-comparison explicitly at `0%`
- Accuracy and disagreement axes are formatted as percentages
- A tolerance ratio of `1` is the pass boundary; values above `1` exceed at least one policy limit
- Repeatability error charts use logarithmic axes because the observed numerical differences can span many orders of magnitude