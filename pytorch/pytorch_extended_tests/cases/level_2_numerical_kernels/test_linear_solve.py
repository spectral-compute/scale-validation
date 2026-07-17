"""Linear solve cases with residuals against the original equations."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _inputs(context: CaseContext) -> dict[str, object]:
    arrays = load_prepared_npz(context, DATASET_ID, "linear_algebra.npz")
    return {
        name: as_profile_tensor(context, value)
        for name, value in arrays.items()
    }


def _record(
    recorder: ObservationRecorder,
    *,
    solutions: dict[str, object],
    residuals: dict[str, object],
) -> None:
    recorder.record("solutions", solutions)
    recorder.record("residuals", residuals)


def _well_conditioned_solve(
    context: CaseContext,
    recorder: ObservationRecorder,
) -> None:
    import torch

    values = _inputs(context)
    matrix = values["well_conditioned_matrix"]
    right_hand_side = values["well_conditioned_rhs"]
    solution = torch.linalg.solve(matrix, right_hand_side)
    _record(
        recorder,
        solutions={"solution": solution},
        residuals={"equation": matrix @ solution - right_hand_side},
    )


def _ill_conditioned_solve(
    context: CaseContext,
    recorder: ObservationRecorder,
) -> None:
    import torch

    values = _inputs(context)
    matrix = values["ill_conditioned_matrix"]
    right_hand_side = values["ill_conditioned_rhs"]
    solution = torch.linalg.solve(matrix, right_hand_side)
    _record(
        recorder,
        solutions={"solution": solution},
        residuals={"equation": matrix @ solution - right_hand_side},
    )


def _matrix_inverse(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    matrix = _inputs(context)["well_conditioned_matrix"]
    inverse = torch.linalg.inv(matrix)
    identity = torch.eye(matrix.shape[0], dtype=matrix.dtype, device=matrix.device)
    _record(
        recorder,
        solutions={"inverse": inverse},
        residuals={
            "left_identity": matrix @ inverse - identity,
            "right_identity": inverse @ matrix - identity,
        },
    )


def _cholesky_solve(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    values = _inputs(context)
    matrix = values["positive_definite_matrix"]
    right_hand_side = values["well_conditioned_rhs"]
    factor = torch.linalg.cholesky(matrix)
    solution = torch.cholesky_solve(right_hand_side, factor)
    _record(
        recorder,
        solutions={"factor": factor, "solution": solution},
        residuals={"equation": matrix @ solution - right_hand_side},
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "well_conditioned_solve": _well_conditioned_solve,
    "ill_conditioned_solve": _ill_conditioned_solve,
    "matrix_inverse": _matrix_inverse,
    "cholesky_solve": _cholesky_solve,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one linear solve case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
