"""Build the concise human-facing summary for the Level 0 examples."""

from __future__ import annotations

import math
from collections.abc import Mapping
from typing import Any

from config.suite_config import LEVEL_0_DEMOS
from pytorch_extended_tests.case_api import CaseContext


def _tensor_l2(values: Mapping[str, Any]) -> float:
    import torch

    total = torch.zeros((), dtype=torch.float64)
    for value in values.values():
        if isinstance(value, Mapping):
            nested = _tensor_l2(value)
            total += nested * nested
        elif isinstance(value, torch.Tensor):
            current = value.detach().to(device="cpu", dtype=torch.float64)
            total += torch.sum(current * current)
    return math.sqrt(float(total.item()))


def _logit_stats(value: Any) -> dict[str, float]:
    import torch

    current = value.detach().to(device="cpu", dtype=torch.float64)
    return {
        "mean": float(current.mean().item()),
        "standard_deviation": float(current.std(unbiased=False).item()),
        "maximum_absolute": float(current.abs().max().item()),
    }


def build_demo_summary(
    context: CaseContext,
    *,
    model_type: str,
    optimiser_name: str,
    labels: Any,
    outputs: Mapping[str, Any],
) -> dict[str, Any]:
    """Return the small set of values shown in level_0_summary.csv."""

    import torch

    losses = [float(value) for value in outputs["loss_series"]]
    initial_logits = outputs["initial_forward"]["logits"]
    evaluation_outputs = outputs["evaluation_outputs"]
    final_step = max(int(name.removeprefix("step_")) for name in evaluation_outputs)
    final_logits = evaluation_outputs[f"step_{final_step}"]["logits"]
    labels_cpu = labels.detach().to(device="cpu", dtype=torch.int64)
    initial_predictions = torch.argmax(initial_logits.detach(), dim=1).to(device="cpu")
    final_predictions = torch.argmax(final_logits.detach(), dim=1).to(device="cpu")
    preview_count = int(LEVEL_0_DEMOS["prediction_preview_count"])

    activations = {
        name.removeprefix("activation."): value
        for name, value in outputs["initial_forward"].items()
        if name.startswith("activation.")
    }
    # Masked attention scores use the dtype minimum as a sentinel
    # Keeping that sentinel in the quick aggregate makes the number useless
    summary_activations = {
        name: value
        for name, value in activations.items()
        if name != "attention_scores"
    }
    activation_names = sorted(summary_activations)
    activation_values = [
        value.detach().to(device="cpu", dtype=torch.float64).reshape(-1)
        for value in summary_activations.values()
    ]
    if activation_values:
        combined_activations = torch.cat(activation_values)
        activation_mean_absolute = float(combined_activations.abs().mean().item())
        activation_maximum_absolute = float(combined_activations.abs().max().item())
    else:
        activation_mean_absolute = 0.0
        activation_maximum_absolute = 0.0

    initial_stats = _logit_stats(initial_logits)
    final_stats = _logit_stats(final_logits)

    return {
        "example": context.case_id,
        "model_type": model_type,
        "optimiser": optimiser_name,
        "training_steps": final_step,
        "profile_id": context.profile_id,
        "device": context.device,
        "dtype": context.autocast_dtype_name or context.dtype_name,
        "sample_count": int(labels_cpu.numel()),
        "class_count": int(final_logits.shape[-1]),
        "initial_loss": losses[0],
        "final_loss": losses[-1],
        "loss_change": losses[-1] - losses[0],
        "initial_accuracy": float((initial_predictions == labels_cpu).float().mean().item()),
        "final_accuracy": float((final_predictions == labels_cpu).float().mean().item()),
        "prediction_changes": int((initial_predictions != final_predictions).sum().item()),
        "initial_predictions": [int(value) for value in initial_predictions[:preview_count]],
        "final_predictions": [int(value) for value in final_predictions[:preview_count]],
        "initial_logits_mean": initial_stats["mean"],
        "initial_logits_standard_deviation": initial_stats["standard_deviation"],
        "initial_logits_maximum_absolute": initial_stats["maximum_absolute"],
        "final_logits_mean": final_stats["mean"],
        "final_logits_standard_deviation": final_stats["standard_deviation"],
        "final_logits_maximum_absolute": final_stats["maximum_absolute"],
        "first_gradient_l2": _tensor_l2(outputs["first_gradients"]),
        "initial_parameter_l2": _tensor_l2(outputs["parameter_states"]["step_0"]),
        "final_parameter_l2": _tensor_l2(
            outputs["parameter_states"][f"step_{final_step}"]
        ),
        "activation_count": len(activation_names),
        "activation_mean_absolute": activation_mean_absolute,
        "activation_maximum_absolute": activation_maximum_absolute,
        "activation_names": activation_names,
    }
