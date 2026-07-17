"""Reduction and statistics cases over canonical prepared inputs."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _inputs(context: CaseContext) -> dict[str, object]:
    arrays = load_prepared_npz(context, DATASET_ID, "reductions.npz")
    return {
        name: as_profile_tensor(context, value)
        for name, value in arrays.items()
    }


def _record(recorder: ObservationRecorder, values: dict[str, object]) -> None:
    recorder.record("results", values)


def _sum_and_mean(context: CaseContext, recorder: ObservationRecorder) -> None:
    values = _inputs(context)
    positive = values["positive"]
    mixed_sign = values["mixed_sign"]
    cube = values["cube"]
    _record(
        recorder,
        {
            "positive_sum_all": positive.sum(),
            "positive_sum_rows": positive.sum(dim=1),
            "positive_mean_columns": positive.mean(dim=0),
            "mixed_sign_sum_all": mixed_sign.sum(),
            "mixed_sign_mean_rows": mixed_sign.mean(dim=1),
            "cube_sum_last_dimension": cube.sum(dim=-1),
            "cube_mean_first_two_dimensions": cube.mean(dim=(0, 1)),
        },
    )


def _variance_and_standard_deviation(
    context: CaseContext,
    recorder: ObservationRecorder,
) -> None:
    values = _inputs(context)
    mixed_sign = values["mixed_sign"]
    cube = values["cube"]
    _record(
        recorder,
        {
            "variance_population_all": mixed_sign.var(correction=0),
            "variance_sample_rows": mixed_sign.var(dim=1, correction=1),
            "standard_deviation_population_columns": mixed_sign.std(
                dim=0,
                correction=0,
            ),
            "cube_variance_last_dimension": cube.var(dim=-1, correction=0),
            "cube_standard_deviation_first_dimension": cube.std(
                dim=0,
                correction=1,
            ),
        },
    )


def _minimum_and_maximum(context: CaseContext, recorder: ObservationRecorder) -> None:
    values = _inputs(context)
    mixed_sign = values["mixed_sign"]
    cube = values["cube"]
    row_minimum = mixed_sign.min(dim=1)
    column_maximum = mixed_sign.max(dim=0)
    cube_minimum = cube.amin(dim=(1, 2))
    cube_maximum = cube.amax(dim=(0, 2))
    _record(
        recorder,
        {
            "global_minimum": mixed_sign.min(),
            "global_maximum": mixed_sign.max(),
            "row_minimum_values": row_minimum.values,
            "row_minimum_indices": row_minimum.indices,
            "column_maximum_values": column_maximum.values,
            "column_maximum_indices": column_maximum.indices,
            "cube_minimum": cube_minimum,
            "cube_maximum": cube_maximum,
        },
    )


def _cumulative_operations(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    mixed_sign = values["mixed_sign"]
    positive = values["positive"]
    integer_values = values["integer_values"]

    # Keep cumprod close to one so lower precision profiles do not overflow immediately
    stable_product_values = 1.0 + (positive[:7, :17] - 5.0) * 1e-3
    _record(
        recorder,
        {
            "mixed_sign_cumsum_rows": torch.cumsum(mixed_sign, dim=1),
            "mixed_sign_cumsum_columns": torch.cumsum(mixed_sign, dim=0),
            "stable_cumprod_rows": torch.cumprod(stable_product_values, dim=1),
            "integer_cumsum_rows": torch.cumsum(integer_values, dim=1),
            "mixed_sign_logcumsumexp_rows": torch.logcumsumexp(mixed_sign, dim=1),
        },
    )


def _vector_and_matrix_norms(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    mixed_sign = values["mixed_sign"]
    cube = values["cube"]
    vector = mixed_sign[0]
    matrix = mixed_sign[:31, :29]
    _record(
        recorder,
        {
            "vector_l1": torch.linalg.vector_norm(vector, ord=1),
            "vector_l2": torch.linalg.vector_norm(vector, ord=2),
            "vector_infinity": torch.linalg.vector_norm(vector, ord=float("inf")),
            "matrix_frobenius": torch.linalg.matrix_norm(matrix, ord="fro"),
            "matrix_one_norm": torch.linalg.matrix_norm(matrix, ord=1),
            "batched_vector_norm": torch.linalg.vector_norm(cube, dim=-1),
        },
    )


def _cancellation_heavy_sum(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    cancellation = values["cancellation"]
    flattened = cancellation.reshape(-1)
    ascending = torch.sort(flattened).values
    descending = ascending.flip(0)
    complete_pattern_length = (flattened.numel() // 5) * 5
    paired = flattened[:complete_pattern_length].reshape(-1, 5)
    _record(
        recorder,
        {
            "source_order_sum": flattened.sum(),
            "ascending_order_sum": ascending.sum(),
            "descending_order_sum": descending.sum(),
            "row_sums": cancellation.sum(dim=1),
            "pattern_sums": paired.sum(dim=1),
            "mean": flattened.mean(),
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "sum_and_mean": _sum_and_mean,
    "variance_and_standard_deviation": _variance_and_standard_deviation,
    "minimum_and_maximum": _minimum_and_maximum,
    "cumulative_operations": _cumulative_operations,
    "vector_and_matrix_norms": _vector_and_matrix_norms,
    "cancellation_heavy_sum": _cancellation_heavy_sum,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one reduction or statistics case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
