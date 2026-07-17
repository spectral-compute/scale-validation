"""Matrix multiplication cases over fixed irregular dimensions."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _inputs(context: CaseContext) -> dict[str, object]:
    arrays = load_prepared_npz(context, DATASET_ID, "matrix_operations.npz")
    return {
        name: as_profile_tensor(context, value)
        for name, value in arrays.items()
    }


def _record(recorder: ObservationRecorder, values: dict[str, object]) -> None:
    recorder.record("results", values)


def _matrix_vector(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    left = values["left"]
    vector = values["vector"]
    _record(
        recorder,
        {
            "mv": torch.mv(left, vector),
            "matmul": torch.matmul(left, vector),
            "transposed_mv": torch.mv(left.transpose(0, 1), left[:, 0]),
        },
    )


def _matrix_matrix(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    left = values["left"]
    right = values["right"]
    _record(
        recorder,
        {
            "mm": torch.mm(left, right),
            "matmul": torch.matmul(left, right),
            "left_gram": left.transpose(0, 1) @ left,
            "right_gram": right @ right.transpose(0, 1),
        },
    )


def _batched_matrix_matrix(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    batch_left = values["batch_left"]
    batch_right = values["batch_right"]
    _record(
        recorder,
        {
            "bmm": torch.bmm(batch_left, batch_right),
            "matmul": torch.matmul(batch_left, batch_right),
            "broadcast_right": torch.matmul(batch_left, batch_right[0]),
        },
    )


def _einsum(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    left = values["einsum_left"]
    right = values["einsum_right"]
    _record(
        recorder,
        {
            "contract_last_dimension": torch.einsum("bij,jk->bik", left, right),
            "batch_gram": torch.einsum("bij,bik->bjk", left, left),
            "diagonal_trace": torch.einsum("bii->b", left[:, :, :7]),
        },
    )


def _inner_and_outer(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    vector = values["vector"]
    second = values["left"][0]
    short_left = vector[:31]
    short_right = second[:31]
    _record(
        recorder,
        {
            "inner": torch.inner(vector, second),
            "dot": torch.dot(vector, second),
            "outer": torch.outer(short_left, short_right),
            "ger": torch.ger(short_left, short_right),
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "matrix_vector": _matrix_vector,
    "matrix_matrix": _matrix_matrix,
    "batched_matrix_matrix": _batched_matrix_matrix,
    "einsum": _einsum,
    "inner_and_outer": _inner_and_outer,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one matrix operation case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
