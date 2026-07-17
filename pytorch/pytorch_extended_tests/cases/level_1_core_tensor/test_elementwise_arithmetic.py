"""Elementwise arithmetic cases over canonical input classes."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _inputs(context: CaseContext) -> dict[str, object]:
    arrays = load_prepared_npz(context, DATASET_ID, "elementwise.npz")
    return {
        name: as_profile_tensor(context, value)
        for name, value in arrays.items()
        if name != "special_values"
    }


def _record(recorder: ObservationRecorder, values: dict[str, object]) -> None:
    recorder.record("results", values)


def _add(context: CaseContext, recorder: ObservationRecorder) -> None:
    values = _inputs(context)
    _record(
        recorder,
        {
            "ordinary_reversed": values["ordinary"] + values["ordinary"].flip(0),
            "near_zero_and_ordinary": values["near_zero"] + values["ordinary"],
            "broadcast": values["broadcast_left"] + values["broadcast_right"],
        },
    )


def _subtract(context: CaseContext, recorder: ObservationRecorder) -> None:
    values = _inputs(context)
    _record(
        recorder,
        {
            "ordinary_reversed": values["ordinary"] - values["ordinary"].flip(0),
            "mixed_sign_and_ordinary": values["mixed_sign"] - values["ordinary"],
            "broadcast": values["broadcast_left"] - values["broadcast_right"],
        },
    )


def _multiply(context: CaseContext, recorder: ObservationRecorder) -> None:
    values = _inputs(context)
    _record(
        recorder,
        {
            "ordinary_unit_interval": values["ordinary"] * values["unit_interval"],
            "near_zero_ordinary": values["near_zero"] * values["ordinary"],
            "broadcast": values["broadcast_left"] * values["broadcast_right"],
        },
    )


def _true_divide(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    denominator = torch.clamp(values["positive"], min=0.125)
    _record(
        recorder,
        {
            "ordinary_by_positive": torch.true_divide(values["ordinary"], denominator),
            "near_zero_by_positive": torch.true_divide(values["near_zero"], denominator),
            "broadcast": torch.true_divide(
                values["broadcast_left"],
                values["broadcast_right"].abs() + 0.5,
            ),
        },
    )


def _floor_divide(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    denominator = torch.clamp(values["positive"], min=0.5)
    _record(
        recorder,
        {
            "ordinary_by_positive": torch.floor_divide(values["ordinary"], denominator),
            "mixed_sign_by_positive": torch.floor_divide(
                values["mixed_sign"],
                denominator,
            ),
        },
    )


def _remainder(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    denominator = torch.clamp(values["positive"], min=0.5)
    _record(
        recorder,
        {
            "ordinary": torch.remainder(values["ordinary"], denominator),
            "mixed_sign": torch.remainder(values["mixed_sign"], denominator),
        },
    )


def _power(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    positive = torch.clamp(values["positive"], min=1e-3, max=16.0)
    bounded = torch.clamp(values["unit_interval"], min=-0.95, max=0.95)
    _record(
        recorder,
        {
            "square": torch.pow(bounded, 2),
            "cube": torch.pow(bounded, 3),
            "square_root": torch.pow(positive, 0.5),
        },
    )


def _minimum_and_maximum(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    _record(
        recorder,
        {
            "minimum": torch.minimum(values["ordinary"], values["mixed_sign"]),
            "maximum": torch.maximum(values["ordinary"], values["mixed_sign"]),
            "fmin": torch.fmin(values["ordinary"], values["mixed_sign"]),
            "fmax": torch.fmax(values["ordinary"], values["mixed_sign"]),
        },
    )


def _clamp(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    _record(
        recorder,
        {
            "symmetric": torch.clamp(values["ordinary"], min=-1.5, max=2.0),
            "lower_only": torch.clamp_min(values["mixed_sign"], -2.5),
            "upper_only": torch.clamp_max(values["mixed_sign"], 3.5),
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "add": _add,
    "subtract": _subtract,
    "multiply": _multiply,
    "true_divide": _true_divide,
    "floor_divide": _floor_divide,
    "remainder": _remainder,
    "power": _power,
    "minimum_and_maximum": _minimum_and_maximum,
    "clamp": _clamp,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one elementwise arithmetic case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
