"""Type-promotion cases with explicit operand dtypes."""

from __future__ import annotations

from collections.abc import Callable

import numpy as np

from cases.common import describe_tensors, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder


def _record(recorder: ObservationRecorder, values: dict[str, object]) -> None:
    import torch

    structure = describe_tensors(values)
    structure["result_types"] = {
        name: str(value.dtype).removeprefix("torch.")
        for name, value in values.items()
        if isinstance(value, torch.Tensor)
    }
    recorder.record("structure", structure)
    recorder.record("values", values)


def _base_values(context: CaseContext) -> np.ndarray:
    return np.linspace(-3.0, 3.0, num=17, dtype=np.float64)


def _integer_and_float(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    integer = torch.arange(-8, 9, device=context.device, dtype=torch.int32)
    floating = torch.tensor(
        _base_values(context),
        device=context.device,
        dtype=context.torch_dtype(),
    )
    _record(
        recorder,
        {
            "add": integer + floating,
            "multiply": integer * floating,
            "true_divide": integer / (floating.abs() + 0.5),
        },
    )


def _float_widths(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    base = _base_values(context)
    float16 = torch.tensor(base, device=context.device, dtype=torch.float16)
    float32 = torch.tensor(base, device=context.device, dtype=torch.float32)
    float64 = torch.tensor(base, device=context.device, dtype=torch.float64)
    profile = torch.tensor(base, device=context.device, dtype=context.torch_dtype())
    lower = float32 if context.torch_dtype() == torch.float64 else float16
    _record(
        recorder,
        {
            "float16_plus_float32": float16 + float32,
            "float32_plus_float64": float32 + float64,
            "lower_plus_profile": lower + profile,
        },
    )


def _scalar_and_tensor(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    tensor = torch.tensor(
        _base_values(context),
        device=context.device,
        dtype=context.torch_dtype(),
    )
    _record(
        recorder,
        {
            "python_integer": tensor + 3,
            "python_float": tensor + 0.25,
            "zero_dimensional_integer": tensor
            + torch.tensor(3, device=context.device, dtype=torch.int64),
            "zero_dimensional_float": tensor
            + torch.tensor(0.25, device=context.device, dtype=torch.float32),
        },
    )


def _boolean_and_numeric(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    numeric = torch.tensor(
        _base_values(context),
        device=context.device,
        dtype=context.torch_dtype(),
    )
    boolean = numeric > 0
    _record(
        recorder,
        {
            "add": boolean + numeric,
            "multiply": boolean * numeric,
            "where": torch.where(boolean, numeric, -numeric),
        },
    )


def _complex_and_real(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    real_dtype = context.torch_dtype()
    complex_dtype = torch.complex128 if real_dtype == torch.float64 else torch.complex64
    real = torch.tensor(_base_values(context), device=context.device, dtype=real_dtype)
    imaginary = torch.linspace(1.0, 2.0, 17, device=context.device, dtype=real_dtype)
    complex_values = torch.complex(real, imaginary).to(dtype=complex_dtype)
    _record(
        recorder,
        {
            "add": complex_values + real,
            "multiply": complex_values * real,
            "divide": complex_values / (real.abs() + 0.5),
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "integer_and_float": _integer_and_float,
    "float_widths": _float_widths,
    "scalar_and_tensor": _scalar_and_tensor,
    "boolean_and_numeric": _boolean_and_numeric,
    "complex_and_real": _complex_and_real,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one type-promotion case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
