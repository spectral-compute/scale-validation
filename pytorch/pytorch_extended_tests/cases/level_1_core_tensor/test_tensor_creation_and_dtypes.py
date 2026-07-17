"""Core tensor creation, conversion and layout cases."""

from __future__ import annotations

from collections.abc import Callable

import numpy as np

from cases.common import (
    as_profile_tensor,
    describe_tensors,
    load_prepared_npz,
    run_registered_case,
)
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _record(
    recorder: ObservationRecorder,
    values: dict[str, object],
    *,
    extra_structure: dict[str, object] | None = None,
) -> None:
    structure = describe_tensors(values)
    if extra_structure:
        structure.update(extra_structure)
    recorder.record("structure", structure)
    recorder.record("values", values)


def _from_numpy(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    inputs = load_prepared_npz(context, DATASET_ID, "elementwise.npz")
    source = np.ascontiguousarray(inputs["ordinary"])
    cpu_view = torch.from_numpy(source)
    converted = cpu_view.to(device=context.device, dtype=context.torch_dtype())
    values = {
        "converted": converted,
        "source_round_trip": converted.to(device="cpu"),
    }
    _record(
        recorder,
        values,
        extra_structure={
            "numpy_source": {
                "shape": list(source.shape),
                "dtype": source.dtype.name,
                "strides_bytes": list(source.strides),
                "is_c_contiguous": bool(source.flags.c_contiguous),
            }
        },
    )


def _zeros_ones_full(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    dtype = context.torch_dtype()
    values = {
        "zeros": torch.zeros((7, 11, 13), device=context.device, dtype=dtype),
        "ones": torch.ones((7, 11, 13), device=context.device, dtype=dtype),
        "full_positive": torch.full(
            (7, 11, 13),
            1.25,
            device=context.device,
            dtype=dtype,
        ),
        "full_negative": torch.full(
            (7, 11, 13),
            -2.5,
            device=context.device,
            dtype=dtype,
        ),
    }
    _record(recorder, values)


def _scalar_construction(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    dtype = context.torch_dtype()
    values = {
        "positive": torch.tensor(3.25, device=context.device, dtype=dtype),
        "negative": torch.tensor(-7.5, device=context.device, dtype=dtype),
        "zero": torch.tensor(0.0, device=context.device, dtype=dtype),
        "integer": torch.tensor(17, device=context.device, dtype=torch.int64),
        "boolean": torch.tensor(True, device=context.device, dtype=torch.bool),
    }
    _record(recorder, values)


def _dtype_conversion(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    inputs = load_prepared_npz(context, DATASET_ID, "elementwise.npz")
    source = as_profile_tensor(context, inputs["ordinary"], dtype=torch.float64)
    values = {
        "profile_dtype": source.to(dtype=context.torch_dtype()),
        "float32": source.to(dtype=torch.float32),
        "int32": source.to(dtype=torch.int32),
        "boolean": source.to(dtype=torch.bool),
    }
    _record(recorder, values)


def _device_round_trip(context: CaseContext, recorder: ObservationRecorder) -> None:
    inputs = load_prepared_npz(context, DATASET_ID, "elementwise.npz")
    original = as_profile_tensor(context, inputs["mixed_sign"])
    cpu_copy = original.to(device="cpu")
    round_trip = cpu_copy.to(device=context.device)
    values = {
        "original": original,
        "cpu_copy": cpu_copy,
        "round_trip": round_trip,
    }
    _record(recorder, values)


def _contiguous_and_non_contiguous(
    context: CaseContext,
    recorder: ObservationRecorder,
) -> None:
    inputs = load_prepared_npz(context, DATASET_ID, "indexing.npz")
    source = as_profile_tensor(context, inputs["source"])
    transposed = source.transpose(0, 2)
    narrowed = source[:, ::2, :]
    values = {
        "source": source,
        "transposed_view": transposed,
        "transposed_contiguous": transposed.contiguous(),
        "strided_view": narrowed,
        "strided_contiguous": narrowed.contiguous(),
    }
    _record(recorder, values)


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "from_numpy": _from_numpy,
    "zeros_ones_full": _zeros_ones_full,
    "scalar_construction": _scalar_construction,
    "dtype_conversion": _dtype_conversion,
    "device_round_trip": _device_round_trip,
    "contiguous_and_non_contiguous": _contiguous_and_non_contiguous,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one tensor creation case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
