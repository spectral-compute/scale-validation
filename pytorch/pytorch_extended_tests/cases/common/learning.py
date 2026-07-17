"""Helpers for loading fixed states and recording learning internals."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from cases.common.data import load_prepared_npz
from pytorch_extended_tests.case_api import CaseContext


MODEL_DATASET_ID = "model_inputs_v1"


def load_module_state(context: CaseContext, module: Any, filename: str) -> None:
    """Load one generated state file into a module without changing its dtype."""

    import torch

    arrays = load_prepared_npz(context, MODEL_DATASET_ID, filename)
    expected = module.state_dict()
    if set(arrays) != set(expected):
        missing = sorted(set(expected) - set(arrays))
        unexpected = sorted(set(arrays) - set(expected))
        raise ValueError(
            f"Initial state does not match the module\n"
            f"Missing keys: {missing}\n"
            f"Unexpected keys: {unexpected}"
        )

    converted: dict[str, Any] = {}
    for name, target in expected.items():
        value = torch.from_numpy(arrays[name])
        converted[name] = value.to(device=target.device, dtype=target.dtype)
    module.load_state_dict(converted, strict=True)


def clone_named_parameters(module: Any) -> dict[str, Any]:
    """Clone all named parameters in state-dictionary order."""

    return {
        name: parameter.detach().clone()
        for name, parameter in module.named_parameters()
    }


def clone_named_gradients(module: Any) -> dict[str, Any]:
    """Clone every parameter gradient and fail clearly when one is missing."""

    gradients: dict[str, Any] = {}
    for name, parameter in module.named_parameters():
        if parameter.grad is None:
            raise RuntimeError(f"Parameter did not receive a gradient: {name}")
        gradients[name] = parameter.grad.detach().clone()
    return gradients


def clone_module_state(module: Any) -> dict[str, Any]:
    """Clone parameters and buffers from a module state dictionary."""

    return {
        name: value.detach().clone()
        for name, value in module.state_dict().items()
    }


def flatten_optimizer_state(optimizer: Any, module: Any) -> dict[str, Any]:
    """Return optimiser tensors with stable parameter names."""

    import torch

    parameter_names = {parameter: name for name, parameter in module.named_parameters()}
    first_parameter = next(module.parameters())
    output: dict[str, Any] = {}

    # Keep the main numeric group settings as tensors as plain SGD has no state tensors
    # This also makes it obvious when two jobs used different optimiser settings
    numeric_group_fields = (
        "lr",
        "momentum",
        "dampening",
        "weight_decay",
        "eps",
        "maximize",
        "nesterov",
        "amsgrad",
    )
    for group_index, group in enumerate(optimizer.param_groups):
        prefix = f"param_group_{group_index}"
        for field in numeric_group_fields:
            value = group.get(field)
            if isinstance(value, (bool, int, float)):
                # Keep optimiser settings independent of the model precision
                # Storing an LR in FP16 can round or underflow a configuration value
                if isinstance(value, bool):
                    stored_value = int(value)
                    dtype = torch.int64
                elif isinstance(value, int):
                    stored_value = value
                    dtype = torch.int64
                else:
                    stored_value = value
                    dtype = torch.float64
                output[f"{prefix}.{field}"] = torch.tensor(
                    stored_value,
                    device=first_parameter.device,
                    dtype=dtype,
                )
        betas = group.get("betas")
        if isinstance(betas, tuple) and len(betas) == 2:
            output[f"{prefix}.beta1"] = torch.tensor(
                betas[0], device=first_parameter.device, dtype=torch.float64
            )
            output[f"{prefix}.beta2"] = torch.tensor(
                betas[1], device=first_parameter.device, dtype=torch.float64
            )

    for parameter, state in optimizer.state.items():
        parameter_name = parameter_names.get(parameter)
        if parameter_name is None:
            raise RuntimeError("Optimiser contains a parameter which is not in the model")
        for state_name, value in state.items():
            if isinstance(value, torch.Tensor):
                output[f"{parameter_name}.{state_name}"] = value.detach().clone()
            elif isinstance(value, (bool, int, float)):
                if isinstance(value, bool):
                    stored_value = int(value)
                    dtype = torch.int64
                elif isinstance(value, int):
                    stored_value = value
                    dtype = torch.int64
                else:
                    stored_value = value
                    dtype = torch.float64
                output[f"{parameter_name}.{state_name}"] = torch.tensor(
                    stored_value,
                    device=first_parameter.device,
                    dtype=dtype,
                )
    return output


def module_to_profile(context: CaseContext, module: Any) -> Any:
    """Move a module to the selected device and ordinary profile dtype."""

    return module.to(device=context.device, dtype=context.torch_dtype())


def tensor_mapping(values: Mapping[str, Any]) -> dict[str, Any]:
    """Detach and clone a named tensor mapping."""

    return {name: value.detach().clone() for name, value in values.items()}
