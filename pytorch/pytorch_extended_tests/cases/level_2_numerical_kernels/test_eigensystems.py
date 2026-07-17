"""Symmetric eigensystem cases with residual and subspace outputs."""

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


def _eigensystem_invariants(matrix: object, *, degenerate_count: int) -> dict[str, object]:
    import torch

    eigenvalues, eigenvectors = torch.linalg.eigh(matrix)
    reconstructed_action = matrix @ eigenvectors
    scaled_vectors = eigenvectors * eigenvalues.unsqueeze(0)
    identity = torch.eye(
        eigenvectors.shape[1],
        dtype=eigenvectors.dtype,
        device=eigenvectors.device,
    )
    subspace = eigenvectors[:, :degenerate_count]
    return {
        "eigenvalues": eigenvalues,
        "eigenvectors": eigenvectors,
        "eigen_residual": reconstructed_action - scaled_vectors,
        "orthogonality_residual": eigenvectors.transpose(-2, -1) @ eigenvectors - identity,
        "leading_subspace_projector": subspace @ subspace.transpose(-2, -1),
    }


def _symmetric_distinct(context: CaseContext, recorder: ObservationRecorder) -> None:
    matrix = _inputs(context)["well_conditioned_matrix"]
    recorder.record(
        "invariants",
        _eigensystem_invariants(matrix, degenerate_count=1),
    )


def _symmetric_degenerate(context: CaseContext, recorder: ObservationRecorder) -> None:
    matrix = _inputs(context)["degenerate_symmetric_matrix"]
    recorder.record(
        "invariants",
        _eigensystem_invariants(matrix, degenerate_count=3),
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "symmetric_distinct": _symmetric_distinct,
    "symmetric_degenerate": _symmetric_degenerate,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one eigensystem case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
