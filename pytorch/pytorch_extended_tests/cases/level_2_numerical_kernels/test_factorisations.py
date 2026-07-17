"""Matrix factorisation cases with reconstruction and orthogonality checks."""

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


def _record(recorder: ObservationRecorder, values: dict[str, object]) -> None:
    recorder.record("invariants", values)


def _qr(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    matrix = _inputs(context)["rectangular_matrix"]
    q, r = torch.linalg.qr(matrix, mode="reduced")
    identity = torch.eye(q.shape[1], dtype=q.dtype, device=q.device)
    reconstruction = q @ r
    _record(
        recorder,
        {
            "q": q,
            "r": r,
            "reconstruction": reconstruction,
            "reconstruction_residual": reconstruction - matrix,
            "orthogonality_residual": q.transpose(-2, -1) @ q - identity,
        },
    )


def _svd(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    matrix = _inputs(context)["svd_matrix"]
    u, singular_values, vh = torch.linalg.svd(matrix, full_matrices=False)
    reconstruction = (u * singular_values.unsqueeze(0)) @ vh
    u_identity = torch.eye(u.shape[1], dtype=u.dtype, device=u.device)
    v_identity = torch.eye(vh.shape[0], dtype=vh.dtype, device=vh.device)
    _record(
        recorder,
        {
            "u": u,
            "singular_values": singular_values,
            "vh": vh,
            "reconstruction": reconstruction,
            "reconstruction_residual": reconstruction - matrix,
            "u_orthogonality_residual": u.transpose(-2, -1) @ u - u_identity,
            "v_orthogonality_residual": vh @ vh.transpose(-2, -1) - v_identity,
        },
    )


def _cholesky(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    matrix = _inputs(context)["positive_definite_matrix"]
    factor = torch.linalg.cholesky(matrix)
    reconstruction = factor @ factor.transpose(-2, -1)
    _record(
        recorder,
        {
            "factor": factor,
            "reconstruction": reconstruction,
            "reconstruction_residual": reconstruction - matrix,
            "strict_upper_triangle": torch.triu(factor, diagonal=1),
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "qr": _qr,
    "svd": _svd,
    "cholesky": _cholesky,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one factorisation case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
