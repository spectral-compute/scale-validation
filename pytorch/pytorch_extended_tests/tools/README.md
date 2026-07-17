# Tools

These are the small maintenance tools used while running and checking the test suite

The manual repeatability and comparison scripts live only in `manual_comparison_stuff/`
They are deliberately kept out of this folder because CI does not run them

## `validate_setup.py`

Checks the central config, catalogue, selected datasets, PyTorch device and case-module imports before a run starts

```bash
python tools/validate_setup.py
```

For a CPU run:

```bash
python tools/validate_setup.py --device cpu
```

It accepts the same basic profile, level and test filters as the suite orchestrator

## `inspect_result_bundle.py`

Checks a completed raw result bundle, including every tensor artefact and its SHA-256 hash

```bash
python tools/inspect_result_bundle.py /tmp/ci_benchmarks/pytorch
```

Use `--json` when a machine-readable validation result is more useful
