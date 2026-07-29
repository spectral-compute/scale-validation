"""Apply and inspect the float32 precision settings used by the suite."""

from __future__ import annotations

from typing import Any


def apply_float32_precision(*, allow_tf32: bool, matmul_precision: str) -> None:
    """Apply the configured matmul and convolution precision without mixing APIs."""

    import torch

    # This public control updates the matmul precision state used by PyTorch 2.9
    # Do not also touch cuda.matmul.allow_tf32 as old and new TF32 APIs must not be mixed
    torch.set_float32_matmul_precision(str(matmul_precision))

    if not hasattr(torch.backends, "cudnn"):
        return

    cudnn = torch.backends.cudnn
    if hasattr(cudnn, "conv") and hasattr(cudnn.conv, "fp32_precision"):
        # PyTorch 2.9 exposes the operator-level cuDNN precision setting
        cudnn.conv.fp32_precision = "tf32" if allow_tf32 else "ieee"
    elif hasattr(cudnn, "allow_tf32"):
        # Keep the legacy fallback for older builds which may still be useful as references
        cudnn.allow_tf32 = bool(allow_tf32)


def _optional_precision_value(owner: Any, attribute: str) -> str | None:
    if owner is None or not hasattr(owner, attribute):
        return None
    return str(getattr(owner, attribute))


def float32_precision_record() -> dict[str, Any]:
    """Return the precision settings exposed by the active PyTorch release."""

    import torch

    cuda_matmul = getattr(getattr(torch.backends, "cuda", None), "matmul", None)
    cudnn = getattr(torch.backends, "cudnn", None)
    cudnn_conv = getattr(cudnn, "conv", None) if cudnn is not None else None

    record: dict[str, Any] = {
        "float32_matmul_precision": torch.get_float32_matmul_precision(),
        "global_fp32_precision": _optional_precision_value(
            torch.backends, "fp32_precision"
        ),
        "cuda_matmul_fp32_precision": _optional_precision_value(
            cuda_matmul, "fp32_precision"
        ),
        "cudnn_backend_fp32_precision": _optional_precision_value(
            cudnn, "fp32_precision"
        ),
        "cudnn_convolution_precision": None,
        "cudnn_precision_api": None,
    }
    if cudnn is None:
        return record

    if cudnn_conv is not None and hasattr(cudnn_conv, "fp32_precision"):
        record["cudnn_convolution_precision"] = str(cudnn_conv.fp32_precision)
        record["cudnn_precision_api"] = "fp32_precision"
    elif hasattr(cudnn, "allow_tf32"):
        record["cudnn_convolution_precision"] = (
            "tf32" if bool(cudnn.allow_tf32) else "ieee"
        )
        record["cudnn_precision_api"] = "allow_tf32"
    return record
