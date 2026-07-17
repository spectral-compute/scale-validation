"""Shared helpers used by the executable case modules."""

from cases.common.composite import run_composite_block
from cases.common.data import load_prepared_npz
from cases.common.demo import build_demo_summary
from cases.common.dispatch import run_registered_case
from cases.common.learning import (
    clone_module_state,
    clone_named_gradients,
    clone_named_parameters,
    flatten_optimizer_state,
    load_module_state,
    module_to_profile,
    tensor_mapping,
)
from cases.common.models import (
    build_attention_block,
    build_linear_classifier,
    build_cnn,
    build_mlp,
    build_sms_transformer,
)
from cases.common.mixed_precision import (
    build_mlp_batch,
    make_grad_scaler,
    parameters_changed,
    scaler_state_record,
)
from cases.common.workloads import WorkloadBatch, run_training_workload
from cases.common.tensors import (
    as_profile_tensor,
    describe_tensor,
    describe_tensors,
    paired_complex_dtype,
)

__all__ = [
    "WorkloadBatch",
    "as_profile_tensor",
    "build_attention_block",
    "build_demo_summary",
    "build_linear_classifier",
    "build_cnn",
    "build_mlp",
    "build_sms_transformer",
    "build_mlp_batch",
    "clone_module_state",
    "clone_named_gradients",
    "clone_named_parameters",
    "describe_tensor",
    "describe_tensors",
    "flatten_optimizer_state",
    "load_module_state",
    "make_grad_scaler",
    "load_prepared_npz",
    "module_to_profile",
    "paired_complex_dtype",
    "parameters_changed",
    "run_composite_block",
    "run_registered_case",
    "run_training_workload",
    "scaler_state_record",
    "tensor_mapping",
]
