"""Transcendental and activation-function cases."""

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
        if name in {"ordinary", "near_zero", "positive", "unit_interval", "mixed_sign"}
    }


def _record(recorder: ObservationRecorder, values: dict[str, object]) -> None:
    recorder.record("results", values)


def _exp_and_log(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    signed = torch.clamp(values["ordinary"], min=-8.0, max=8.0)
    positive = torch.clamp(values["positive"], min=1e-4, max=20.0)
    unit = torch.clamp(values["unit_interval"], min=-0.95, max=0.95)
    _record(
        recorder,
        {
            "exp": torch.exp(signed),
            "expm1": torch.expm1(signed),
            "log": torch.log(positive),
            "log2": torch.log2(positive),
            "log10": torch.log10(positive),
            "log1p": torch.log1p(unit),
        },
    )


def _sqrt_and_rsqrt(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    positive = torch.clamp(values["positive"], min=1e-4, max=20.0)
    small = torch.clamp(values["near_zero"].abs(), min=1e-4)
    _record(
        recorder,
        {
            "sqrt_positive": torch.sqrt(positive),
            "rsqrt_positive": torch.rsqrt(positive),
            "sqrt_small": torch.sqrt(small),
            "rsqrt_small": torch.rsqrt(small),
        },
    )


def _trigonometric(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    angles = values["unit_interval"] * 1.25
    _record(
        recorder,
        {
            "sin": torch.sin(angles),
            "cos": torch.cos(angles),
            "tan": torch.tan(angles),
            "asin": torch.asin(values["unit_interval"]),
            "acos": torch.acos(values["unit_interval"]),
            "atan": torch.atan(values["ordinary"]),
        },
    )


def _hyperbolic(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    bounded = torch.clamp(values["mixed_sign"], min=-4.0, max=4.0)
    inverse_input = torch.clamp(values["unit_interval"], min=-0.95, max=0.95)
    _record(
        recorder,
        {
            "sinh": torch.sinh(bounded),
            "cosh": torch.cosh(bounded),
            "tanh": torch.tanh(bounded),
            "asinh": torch.asinh(bounded),
            "atanh": torch.atanh(inverse_input),
        },
    )


def _sigmoid_family(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch
    import torch.nn.functional as functional

    values = _inputs(context)
    bounded = torch.clamp(values["ordinary"], min=-12.0, max=12.0)
    _record(
        recorder,
        {
            "sigmoid": torch.sigmoid(bounded),
            "log_sigmoid": functional.logsigmoid(bounded),
            "softplus": functional.softplus(bounded),
            "silu": functional.silu(bounded),
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "exp_and_log": _exp_and_log,
    "sqrt_and_rsqrt": _sqrt_and_rsqrt,
    "trigonometric": _trigonometric,
    "hyperbolic": _hyperbolic,
    "sigmoid_family": _sigmoid_family,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one transcendental-function case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
