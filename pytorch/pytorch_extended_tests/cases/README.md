# Case modules

This folder contains the executable examples whose raw outputs are retained by CI

Each test file maps directly to one entry in `config/test_catalogue.py`. The files produce named observations but do not decide whether those observations are numerically close enough to another build

## Current implementation status

- Level 0 quick model demonstrations are implemented and enabled by default
- Level 1 core tensor behaviour is implemented
- Level 2 numerical kernels is implemented
- Level 3 autograd and learning components is implemented
- Level 4 precision modes, mixed precision and serialisation is implemented
- Level 5 composite MLP, CNN and attention models are implemented
- Level 6 tabular, image and Transformer workloads are implemented

All levels are implemented. The default enabled-level list contains Level 0 only so a new build gets a quick first check before the full suite is enabled

## Shared helpers

The `common/` folder contains the prepared-data loader, tensor conversion helpers, fixed model builders, learning-state helpers, mixed-precision helpers, the shared composite-model and workload loops and the small case dispatcher

Case files should keep global choices in `config/suite_config.py` rather than adding local seeds, sizes, learning rates, scaler values or execution settings
