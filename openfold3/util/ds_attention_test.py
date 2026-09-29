"""Ubiquitin accuracy test with DeepSpeed attention (a file: spawned workers need one)."""

import os
import sys

# Use the checkout, like pytest.
sys.path.insert(0, os.getcwd())

import pytest  # noqa: E402

from openfold3.tests.inference import helpers  # noqa: E402

if __name__ == "__main__":
    helpers.inference_test_yaml_str += """\
  custom:
    settings:
      memory:
        eval:
          use_deepspeed_evo_attention: true
"""
    sys.exit(pytest.main([
        "openfold3/tests/inference/test_inference_full.py",
        "-m", "slow",
        "-k", "ubiquitin and no_msa-no_templates",
        "-v", "--log-cli-level=INFO",
    ]))
