"""Small public API used by the individual test case modules."""

from __future__ import annotations

from contextlib import AbstractContextManager, nullcontext
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Protocol

from config.suite_config import DATASET_PATHS, derive_seed


class UnsupportedCase(RuntimeError):
    """Raised by a case when the current backend cannot support it."""


class ObservationRecorder(Protocol):
    """Interface exposed to case modules for recording named outputs."""

    def record(
        self,
        output_id: str,
        value: Any,
        *,
        coordinates: Mapping[str, Any] | None = None,
    ) -> None:
        """Record one output declared in the test catalogue."""


@dataclass(frozen=True, slots=True)
class CaseContext:
    """Execution details supplied to one case function."""

    test_id: str
    case_id: str
    profile_id: str
    device: str
    dtype_name: str
    autocast_dtype_name: str | None
    seed: int
    temporary_directory: Path

    def dataset_path(self, dataset_id: str) -> Path:
        """Return the configured prepared directory for a dataset ID."""

        try:
            return DATASET_PATHS[dataset_id]
        except KeyError as exc:
            raise KeyError(f"Unknown dataset ID: {dataset_id}") from exc

    def seed_for(self, name: str) -> int:
        """Derive a stable child seed for a distinct random stream."""

        if not name:
            raise ValueError("Seed stream names must not be empty")
        return derive_seed(self.test_id, self.profile_id, self.case_id, name)

    def torch_dtype(self) -> Any:
        """Resolve the configured dtype without importing PyTorch in config code."""

        import torch

        try:
            return getattr(torch, self.dtype_name)
        except AttributeError as exc:
            raise ValueError(f"Unknown PyTorch dtype: {self.dtype_name}") from exc

    def autocast(self) -> AbstractContextManager[Any]:
        """Return the configured autocast context, or a no-op context."""

        if self.autocast_dtype_name is None:
            return nullcontext()

        import torch

        try:
            autocast_dtype = getattr(torch, self.autocast_dtype_name)
        except AttributeError as exc:
            raise ValueError(
                f"Unknown PyTorch autocast dtype: {self.autocast_dtype_name}"
            ) from exc

        return torch.autocast(
            device_type=torch.device(self.device).type,
            dtype=autocast_dtype,
            enabled=True,
        )
