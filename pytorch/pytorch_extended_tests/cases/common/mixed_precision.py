"""Shared helpers for the mixed-precision cases."""

from __future__ import annotations

from typing import Any

from config.suite_config import AMP_GRAD_SCALER
from cases.common.data import load_prepared_npz
from cases.common.learning import (
    clone_named_gradients,
    clone_named_parameters,
    load_module_state,
    module_to_profile,
)
from cases.common.models import build_mlp
from cases.common.tensors import as_profile_tensor
from pytorch_extended_tests.case_api import CaseContext


MODEL_DATASET_ID = "model_inputs_v1"


def build_mlp_batch(context: CaseContext) -> tuple[Any, Any, Any]:
    """Build the fixed MLP and return its canonical input and labels."""

    import torch

    arrays = load_prepared_npz(context, MODEL_DATASET_ID, "block_inputs.npz")
    value = as_profile_tensor(context, arrays["mlp_input"], requires_grad=True)
    labels = as_profile_tensor(context, arrays["mlp_labels"], dtype=torch.int64)
    model = module_to_profile(context, build_mlp())
    load_module_state(context, model, "mlp_initial_state.npz")
    return model, value, labels


def make_grad_scaler(context: CaseContext) -> Any:
    """Build the configured GradScaler using the public device-aware API."""

    import torch

    settings = AMP_GRAD_SCALER
    device_type = torch.device(context.device).type
    try:
        return torch.amp.GradScaler(
            device_type,
            init_scale=float(settings["initial_scale"]),
            growth_factor=float(settings["growth_factor"]),
            backoff_factor=float(settings["backoff_factor"]),
            growth_interval=int(settings["growth_interval"]),
            enabled=True,
        )
    except TypeError:
        # Older PyTorch releases exposed the CUDA scaler without a device argument
        # Keep this fallback until all tested builds use the newer torch.amp API
        return torch.cuda.amp.GradScaler(
            init_scale=float(settings["initial_scale"]),
            growth_factor=float(settings["growth_factor"]),
            backoff_factor=float(settings["backoff_factor"]),
            growth_interval=int(settings["growth_interval"]),
            enabled=True,
        )


def parameters_changed(before: dict[str, Any], after: dict[str, Any]) -> bool:
    """Return whether any named parameter changed exactly."""

    import torch

    if before.keys() != after.keys():
        raise ValueError("Parameter mappings do not have the same keys")
    return any(not torch.equal(before[name], after[name]) for name in before)


def scaler_state_record(
    scaler: Any,
    *,
    initial_scale: float,
    step_requested: bool,
    step_skipped: bool,
    overflow_injected: bool,
) -> dict[str, Any]:
    """Return the public scaler state with the decisions made by this case."""

    state = dict(scaler.state_dict())
    return {
        "enabled": bool(scaler.is_enabled()),
        "initial_scale": float(initial_scale),
        "final_scale": float(scaler.get_scale()),
        "growth_factor": float(state.get("growth_factor", 1.0)),
        "backoff_factor": float(state.get("backoff_factor", 1.0)),
        "growth_interval": int(state.get("growth_interval", 0)),
        "growth_tracker": int(state.get("_growth_tracker", 0)),
        "step_requested": bool(step_requested),
        "step_skipped": bool(step_skipped),
        "overflow_injected": bool(overflow_injected),
    }
