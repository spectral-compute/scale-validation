#!/bin/bash

set -ETeuo pipefail

# Triton needs ptxas, which SCALE lacks.
sed -Ee 's|"use_triton_triangle_kernels": True,|"use_triton_triangle_kernels": False,|' \
    -i openfold-3/openfold3/projects/of3_all_atom/config/model_config.py
! grep -q '"use_triton_triangle_kernels": True' \
    openfold-3/openfold3/projects/of3_all_atom/config/model_config.py
