"""Lossless tensor storage used by the result artifact writer."""

from __future__ import annotations

import hashlib
import os
import tempfile
from pathlib import Path
from typing import Any

import numpy as np


RAW_TENSOR_FORMAT = "raw_little_endian_v1"


def is_tensor_like(value: Any) -> bool:
    """Return whether a value is a PyTorch tensor or NumPy array."""

    if isinstance(value, np.ndarray):
        return True
    try:
        import torch
    except ImportError:
        return False
    return isinstance(value, torch.Tensor)


def _normalise_numpy_array(array: np.ndarray) -> tuple[np.ndarray, str, str]:
    if array.dtype.hasobject:
        raise TypeError("Object arrays cannot be stored as tensor artifacts")

    contiguous = np.ascontiguousarray(array)
    logical_dtype = contiguous.dtype.name
    storage_dtype = contiguous.dtype.newbyteorder("<")
    little_endian = contiguous.astype(storage_dtype, copy=False)
    return little_endian, logical_dtype, little_endian.dtype.str


def _normalise_torch_tensor(value: Any) -> tuple[np.ndarray, str, str, dict[str, Any]]:
    import torch

    tensor = value.detach()
    source = {
        "source_device": str(tensor.device),
        "source_strides": list(tensor.stride()),
        "source_contiguous": tensor.is_contiguous(),
        "requires_grad": bool(value.requires_grad),
    }
    cpu_tensor = tensor.to(device="cpu").contiguous()
    logical_dtype = str(cpu_tensor.dtype).removeprefix("torch.")

    if cpu_tensor.dtype == torch.bfloat16:
        # NumPy has no portable bfloat16 dtype
        # Store the exact two-byte representation and keep the logical dtype separately
        array = cpu_tensor.view(torch.uint16).numpy()
        storage_dtype = np.dtype("<u2")
        array = array.astype(storage_dtype, copy=False)
        return array, logical_dtype, storage_dtype.str, source

    try:
        array = cpu_tensor.numpy()
    except (TypeError, RuntimeError) as exc:
        raise TypeError(f"Unsupported tensor dtype for artifact storage: {cpu_tensor.dtype}") from exc

    array, _, storage_name = _normalise_numpy_array(array)
    return array, logical_dtype, storage_name, source

def _as_numpy_for_statistics(value: object) -> np.ndarray:
    """Copy a tensor to CPU before using NumPy for summary statistics."""

    try:
        import torch
    except ImportError:
        torch = None

    if torch is not None and isinstance(value, torch.Tensor):
        tensor = value.detach()

        # NumPy cannot read CUDA tensors directly
        if tensor.device.type != "cpu":
            tensor = tensor.cpu()

        # NumPy generally has no native bfloat16 representation
        # Float32 is sufficient here because this copy is only used for counts
        if tensor.dtype == torch.bfloat16:
            tensor = tensor.to(torch.float32)

        return tensor.numpy()

    return np.asarray(value)


def _exceptional_value_counts(value: Any, numel: int) -> dict[str, int | None]:
    try:
        import torch
    except ImportError:
        torch = None

    if torch is not None and isinstance(value, torch.Tensor):
        tensor = value.detach().to(device="cpu")
        if tensor.dtype == torch.bfloat16:
            tensor = tensor.to(dtype=torch.float32)
        if tensor.is_floating_point() or tensor.is_complex():
            finite_count = int(torch.isfinite(tensor).sum().item())
            nan_count = int(torch.isnan(tensor).sum().item())
            infinity_count = int(torch.isinf(tensor).sum().item())
            if tensor.is_complex():
                positive_infinity_count = None
                negative_infinity_count = None
            else:
                positive_infinity_count = int(torch.isposinf(tensor).sum().item())
                negative_infinity_count = int(torch.isneginf(tensor).sum().item())
            return {
                "finite_count": finite_count,
                "nan_count": nan_count,
                "infinity_count": infinity_count,
                "positive_infinity_count": positive_infinity_count,
                "negative_infinity_count": negative_infinity_count,
            }

    array = _as_numpy_for_statistics(value)
    if np.issubdtype(array.dtype, np.inexact):
        finite = np.isfinite(array)
        nan = np.isnan(array)
        infinity = np.isinf(array)
        if np.issubdtype(array.dtype, np.complexfloating):
            positive_infinity_count = None
            negative_infinity_count = None
        else:
            positive_infinity_count = int(np.isposinf(array).sum())
            negative_infinity_count = int(np.isneginf(array).sum())
        return {
            "finite_count": int(finite.sum()),
            "nan_count": int(nan.sum()),
            "infinity_count": int(infinity.sum()),
            "positive_infinity_count": positive_infinity_count,
            "negative_infinity_count": negative_infinity_count,
        }

    return {
        "finite_count": numel,
        "nan_count": 0,
        "infinity_count": 0,
        "positive_infinity_count": 0,
        "negative_infinity_count": 0,
    }


def _atomic_write_bytes(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(file_descriptor, "wb") as output:
            output.write(payload)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def write_tensor_artifact(
    value: Any,
    *,
    destination: Path,
    relative_path: Path,
) -> dict[str, Any]:
    """Write one tensor as canonical bytes and return its descriptor."""

    try:
        import torch
    except ImportError:
        torch = None

    if torch is not None and isinstance(value, torch.Tensor):
        array, logical_dtype, storage_dtype, source = _normalise_torch_tensor(value)
        shape = list(value.shape)
    elif isinstance(value, np.ndarray):
        array, logical_dtype, storage_dtype = _normalise_numpy_array(value)
        source = {
            "source_device": "cpu",
            "source_strides_bytes": list(value.strides),
            "source_contiguous": bool(value.flags.c_contiguous),
            "requires_grad": False,
        }
        shape = list(value.shape)
    else:
        raise TypeError(f"Expected a tensor or NumPy array, got {type(value)!r}")

    payload = array.tobytes(order="C")
    checksum = hashlib.sha256(payload).hexdigest()
    _atomic_write_bytes(destination, payload)
    numel = int(np.prod(shape, dtype=np.int64)) if shape else 1

    return {
        "artifact_type": "tensor",
        "storage_format": RAW_TENSOR_FORMAT,
        "relative_path": relative_path.as_posix(),
        "sha256": checksum,
        "byte_length": len(payload),
        "logical_dtype": logical_dtype,
        "storage_dtype": storage_dtype,
        "byte_order": "little",
        "shape": shape,
        "numel": numel,
        **source,
        **_exceptional_value_counts(value, numel),
    }
