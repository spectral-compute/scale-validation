"""Convolution cases using fixed inputs, weights and biases."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _inputs(context: CaseContext) -> dict[str, object]:
    arrays = load_prepared_npz(context, DATASET_ID, "convolutions.npz")
    return {
        name: as_profile_tensor(context, value)
        for name, value in arrays.items()
    }


def _record(recorder: ObservationRecorder, values: dict[str, object]) -> None:
    recorder.record("results", values)


def _conv1d(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    values = _inputs(context)
    source = values["conv1d_input"]
    weight = values["conv1d_weight"]
    bias = values["conv1d_bias"]
    _record(
        recorder,
        {
            "valid": functional.conv1d(source, weight, bias),
            "same_length": functional.conv1d(source, weight, bias, padding=2),
            "strided": functional.conv1d(source, weight, bias, stride=2, padding=2),
            "dilated": functional.conv1d(source, weight, bias, dilation=2, padding=4),
        },
    )


def _conv2d(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    values = _inputs(context)
    source = values["conv2d_input"]
    weight = values["conv2d_weight"]
    bias = values["conv2d_bias"]
    _record(
        recorder,
        {
            "valid": functional.conv2d(source, weight, bias),
            "same_shape": functional.conv2d(source, weight, bias, padding=1),
            "strided": functional.conv2d(source, weight, bias, stride=2, padding=1),
            "dilated": functional.conv2d(source, weight, bias, dilation=2, padding=2),
        },
    )


def _grouped_conv2d(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    values = _inputs(context)
    source = values["grouped_conv2d_input"]
    weight = values["grouped_conv2d_weight"]
    bias = values["grouped_conv2d_bias"]
    _record(
        recorder,
        {
            "groups_two": functional.conv2d(
                source,
                weight,
                bias,
                padding=1,
                groups=2,
            ),
            "groups_two_strided": functional.conv2d(
                source,
                weight,
                bias,
                stride=2,
                padding=1,
                groups=2,
            ),
        },
    )


def _conv3d(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    values = _inputs(context)
    source = values["conv3d_input"]
    weight = values["conv3d_weight"]
    bias = values["conv3d_bias"]
    _record(
        recorder,
        {
            "valid": functional.conv3d(source, weight, bias),
            "same_shape": functional.conv3d(source, weight, bias, padding=1),
            "strided": functional.conv3d(source, weight, bias, stride=2, padding=1),
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "conv1d": _conv1d,
    "conv2d": _conv2d,
    "grouped_conv2d": _grouped_conv2d,
    "conv3d": _conv3d,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one convolution case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
