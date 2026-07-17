"""Indexing, view and shape-manipulation cases."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import (
    as_profile_tensor,
    describe_tensors,
    load_prepared_npz,
    run_registered_case,
)
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _inputs(context: CaseContext) -> dict[str, object]:
    arrays = load_prepared_npz(context, DATASET_ID, "indexing.npz")
    return {
        "source": as_profile_tensor(context, arrays["source"]),
        "row_indices": as_profile_tensor(context, arrays["row_indices"]),
        "column_indices": as_profile_tensor(context, arrays["column_indices"]),
        "gather_indices": as_profile_tensor(context, arrays["gather_indices"]),
        "boolean_mask": as_profile_tensor(context, arrays["boolean_mask"]),
        "scatter_values": as_profile_tensor(context, arrays["scatter_values"]),
    }


def _record(recorder: ObservationRecorder, values: dict[str, object]) -> None:
    recorder.record("structure", describe_tensors(values))
    recorder.record("values", values)


def _basic_slicing(context: CaseContext, recorder: ObservationRecorder) -> None:
    source = _inputs(context)["source"]
    _record(
        recorder,
        {
            "middle_block": source[1:6, 2:10, 3:12],
            "strided": source[::2, 1::3, ::2],
            "single_plane": source[3],
        },
    )


def _advanced_indexing(context: CaseContext, recorder: ObservationRecorder) -> None:
    values = _inputs(context)
    source = values["source"]
    rows = values["row_indices"]
    columns = values["column_indices"]
    _record(
        recorder,
        {
            "selected_rows": source[rows],
            "paired_rows_and_columns": source[rows, :, columns],
            "selected_columns": source[:, :, columns],
        },
    )


def _boolean_masking(context: CaseContext, recorder: ObservationRecorder) -> None:
    values = _inputs(context)
    source = values["source"]
    mask = values["boolean_mask"]
    _record(
        recorder,
        {
            "selected": source[mask],
            "filled": source.masked_fill(mask, -3.0),
        },
    )


def _gather(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    source = values["source"]
    indices = values["gather_indices"]
    _record(
        recorder,
        {
            "gather_last_dimension": torch.gather(source, dim=2, index=indices),
            "take_along_last_dimension": torch.take_along_dim(
                source,
                indices,
                dim=2,
            ),
        },
    )


def _scatter(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    source = values["source"]
    scatter_values = values["scatter_values"]

    # Keep the indices unique along the scatter dimension
    # Duplicate indices would turn this into a nondeterminism test instead
    base_indices = torch.tensor(
        [0, 3, 6, 9, 12],
        device=context.device,
        dtype=torch.int64,
    )
    indices = base_indices.view(1, 1, 5).expand_as(scatter_values)
    scattered = torch.zeros_like(source).scatter(2, indices, scatter_values)
    added = torch.zeros_like(source).scatter_add(2, indices, scatter_values)
    _record(
        recorder,
        {
            "scatter": scattered,
            "scatter_add": added,
        },
    )


def _reshape_and_view(context: CaseContext, recorder: ObservationRecorder) -> None:
    source = _inputs(context)["source"]
    _record(
        recorder,
        {
            "flatten": source.flatten(),
            "reshape_2d": source.reshape(7, 11 * 13),
            "view_2d": source.view(7 * 11, 13),
            "unflatten": source.flatten().unflatten(0, (7, 11, 13)),
        },
    )


def _transpose_and_permute(context: CaseContext, recorder: ObservationRecorder) -> None:
    source = _inputs(context)["source"]
    _record(
        recorder,
        {
            "transpose": source.transpose(0, 2),
            "permute": source.permute(2, 0, 1),
            "movedim": source.movedim((0, 2), (2, 0)),
        },
    )


def _concatenate_and_stack(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    source = _inputs(context)["source"]
    first = source[:3]
    second = source[3:6]
    _record(
        recorder,
        {
            "concatenate": torch.cat((first, second), dim=0),
            "stack": torch.stack((source[0], source[1], source[2]), dim=0),
            "column_concatenate": torch.cat((source[:, :, :5], source[:, :, 5:]), dim=2),
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "basic_slicing": _basic_slicing,
    "advanced_indexing": _advanced_indexing,
    "boolean_masking": _boolean_masking,
    "gather": _gather,
    "scatter": _scatter,
    "reshape_and_view": _reshape_and_view,
    "transpose_and_permute": _transpose_and_permute,
    "concatenate_and_stack": _concatenate_and_stack,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one indexing or shape case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
