"""Tensor conversion and structure helpers for case outputs."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

import numpy as np

from pytorch_extended_tests.case_api import CaseContext


def paired_complex_dtype(dtype: Any) -> Any:
    """Return the complex dtype corresponding to a real PyTorch dtype."""

    import torch

    if dtype == torch.float64:
        return torch.complex128
    return torch.complex64


def as_profile_tensor(
    context: CaseContext,
    value: np.ndarray | Any,
    *,
    dtype: Any | None = None,
    requires_grad: bool = False,
) -> Any:
    """Move an array to the case device with predictable dtype handling."""

    import torch

    array = np.asarray(value)
    tensor = torch.from_numpy(np.ascontiguousarray(array))

    if dtype is None:
        if np.issubdtype(array.dtype, np.floating):
            dtype = context.torch_dtype()
        elif np.issubdtype(array.dtype, np.complexfloating):
            dtype = paired_complex_dtype(context.torch_dtype())

    tensor = tensor.to(device=context.device, dtype=dtype)
    if requires_grad:
        if not tensor.is_floating_point() and not tensor.is_complex():
            raise TypeError("Only floating-point and complex tensors can require gradients")
        tensor.requires_grad_(True)
    return tensor


def describe_tensor(value: Any) -> dict[str, Any]:
    """Return comparison-friendly tensor structure without embedding values."""

    import torch

    if not isinstance(value, torch.Tensor):
        raise TypeError(f"Expected a PyTorch tensor, got {type(value)!r}")

    return {
        "shape": list(value.shape),
        "dtype": str(value.dtype).removeprefix("torch."),
        "strides": list(value.stride()),
        "layout": str(value.layout).removeprefix("torch."),
        "is_contiguous": bool(value.is_contiguous()),
        "numel": value.numel(),
        "requires_grad": bool(value.requires_grad),
    }


def describe_tensors(values: Mapping[str, Any]) -> dict[str, Any]:
    """Describe a named tensor mapping in stable insertion order."""

    return {name: describe_tensor(value) for name, value in values.items()}
