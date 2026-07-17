"""Pooling cases over the prepared convolution inputs."""

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
        if name.endswith("_input")
    }


def _empty_indices(context: CaseContext) -> object:
    import torch

    return torch.empty(0, dtype=torch.int64, device=context.device)


def _record(
    recorder: ObservationRecorder,
    *,
    values: dict[str, object],
    indices: dict[str, object],
) -> None:
    recorder.record("values", values)
    recorder.record("indices", indices)


def _max_pool1d(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    source = _inputs(context)["conv1d_input"]
    values, indices = functional.max_pool1d(
        source,
        kernel_size=3,
        stride=2,
        padding=1,
        return_indices=True,
    )
    ceil_values, ceil_indices = functional.max_pool1d(
        source,
        kernel_size=4,
        stride=3,
        padding=1,
        ceil_mode=True,
        return_indices=True,
    )
    _record(
        recorder,
        values={"standard": values, "ceil_mode": ceil_values},
        indices={"standard": indices, "ceil_mode": ceil_indices},
    )


def _max_pool2d(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    source = _inputs(context)["conv2d_input"]
    values, indices = functional.max_pool2d(
        source,
        kernel_size=(3, 2),
        stride=(2, 2),
        padding=(1, 0),
        return_indices=True,
    )
    dilated_values, dilated_indices = functional.max_pool2d(
        source,
        kernel_size=3,
        stride=2,
        padding=1,
        dilation=2,
        return_indices=True,
    )
    _record(
        recorder,
        values={"standard": values, "dilated": dilated_values},
        indices={"standard": indices, "dilated": dilated_indices},
    )


def _average_pool2d(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    source = _inputs(context)["conv2d_input"]
    _record(
        recorder,
        values={
            "include_padding": functional.avg_pool2d(
                source,
                kernel_size=3,
                stride=2,
                padding=1,
                count_include_pad=True,
            ),
            "exclude_padding": functional.avg_pool2d(
                source,
                kernel_size=3,
                stride=2,
                padding=1,
                count_include_pad=False,
            ),
            "divisor_override": functional.avg_pool2d(
                source,
                kernel_size=2,
                stride=2,
                divisor_override=5,
            ),
        },
        indices={"not_applicable": _empty_indices(context)},
    )


def _adaptive_average_pool2d(
    context: CaseContext,
    recorder: ObservationRecorder,
) -> None:
    import torch.nn.functional as functional

    source = _inputs(context)["conv2d_input"]
    _record(
        recorder,
        values={
            "one_by_one": functional.adaptive_avg_pool2d(source, output_size=(1, 1)),
            "irregular": functional.adaptive_avg_pool2d(source, output_size=(5, 7)),
            "partially_preserved": functional.adaptive_avg_pool2d(
                source,
                output_size=(None, 4),
            ),
        },
        indices={"not_applicable": _empty_indices(context)},
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "max_pool1d": _max_pool1d,
    "max_pool2d": _max_pool2d,
    "average_pool2d": _average_pool2d,
    "adaptive_average_pool2d": _adaptive_average_pool2d,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one pooling case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
