"""Load the canonical prepared arrays used by the case modules."""

from __future__ import annotations

from pathlib import Path

import numpy as np

from pytorch_extended_tests.case_api import CaseContext


def load_prepared_npz(
    context: CaseContext,
    dataset_id: str,
    filename: str,
) -> dict[str, np.ndarray]:
    """Load one prepared NPZ file and return independent NumPy arrays."""

    path = context.dataset_path(dataset_id) / filename
    if not path.is_file():
        raise FileNotFoundError(
            f"Prepared dataset file is missing: {path}\n"
            "Run datasets/generate_datasets.py before running the suite"
        )

    try:
        with np.load(path, allow_pickle=False) as archive:
            # Copy these so a case can safely use an in-place operation
            # The next case should still see the original prepared input
            return {name: np.array(archive[name], copy=True) for name in archive.files}
    except (OSError, ValueError) as exc:
        raise RuntimeError(f"Could not load prepared dataset file: {path}") from exc


def require_prepared_file(context: CaseContext, dataset_id: str, filename: str) -> Path:
    """Return one prepared file path after checking that it exists."""

    path = context.dataset_path(dataset_id) / filename
    if not path.is_file():
        raise FileNotFoundError(f"Prepared dataset file is missing: {path}")
    return path
