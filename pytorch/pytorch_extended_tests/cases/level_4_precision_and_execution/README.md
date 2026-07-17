# Level 4 precision and execution cases

This level checks execution modes which can change the numerical path without changing the high-level model code

- `test_fp32_precision_modes.py` records matmul and convolution outputs under the configured strict, high and medium float32 modes
- `test_amp_fp16.py` records CUDA FP16 autocast, unscaled gradients, optimiser-step behaviour and an intentionally injected overflow
- `test_amp_bfloat16.py` records BF16 autocast on supported CPU or CUDA builds
- `test_serialisation_roundtrip.py` checks tensor, model, optimiser and complete-checkpoint save/load paths

The precision settings and GradScaler values are centralised in `config/suite_config.py`
