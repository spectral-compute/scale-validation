"""Machine-readable records written by the execution harness."""

from __future__ import annotations

import math
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any, Mapping

import numpy as np

from config.suite_config import (
    RESULT_FORMAT_VERSION,
    SUITE_VERSION,
    TEST_CATALOGUE_VERSION,
)


OBSERVATION_STATUSES = {
    "produced",
    "skipped_unsupported",
    "failed_to_produce",
}
CASE_STATUSES = {"passed", "failed", "skipped_unsupported"}
TASK_STATUSES = {"passed", "failed", "skipped_unsupported", "timed_out"}


def utc_now() -> str:
    """Return an ISO timestamp in UTC."""

    return datetime.now(timezone.utc).isoformat()


def json_safe(value: Any) -> Any:
    """Convert ordinary Python and NumPy values into strict JSON data."""

    if value is None or isinstance(value, (str, bool, int)):
        return value
    if isinstance(value, float):
        if math.isfinite(value):
            return value
        if math.isnan(value):
            label = "nan"
        elif value > 0:
            label = "positive_infinity"
        else:
            label = "negative_infinity"
        return {"value_type": "special_float", "value": label}
    if isinstance(value, np.generic):
        return json_safe(value.item())
    if isinstance(value, Path):
        return value.as_posix()
    if isinstance(value, Enum):
        return json_safe(value.value)
    if isinstance(value, Mapping):
        converted: dict[str, Any] = {}
        for key, item in value.items():
            if not isinstance(key, str):
                raise TypeError("JSON record mappings must use string keys")
            converted[key] = json_safe(item)
        return converted
    if isinstance(value, (list, tuple)):
        return [json_safe(item) for item in value]
    raise TypeError(f"Value cannot be represented in a JSON record: {type(value)!r}")


@dataclass(frozen=True, slots=True)
class ObservationRecord:
    """One declared case output and its stored payload."""

    test_id: str
    case_id: str
    profile_id: str
    output_id: str
    kind: str
    importance: str
    status: str
    seed: int
    payload: Any | None = None
    coordinates: Mapping[str, Any] | None = None
    reason: str | None = None
    created_at_utc: str = ""

    def __post_init__(self) -> None:
        if self.status not in OBSERVATION_STATUSES:
            raise ValueError(f"Unknown observation status: {self.status}")

    def as_dict(self) -> dict[str, Any]:
        """Return the record with the shared format metadata attached."""

        data = asdict(self)
        if not data["created_at_utc"]:
            data["created_at_utc"] = utc_now()
        data.update(
            {
                "result_format_version": RESULT_FORMAT_VERSION,
                "suite_version": SUITE_VERSION,
                "test_catalogue_version": TEST_CATALOGUE_VERSION,
            }
        )
        return json_safe(data)


@dataclass(frozen=True, slots=True)
class CaseExecutionRecord:
    """Execution status for one test case and profile."""

    test_id: str
    case_id: str
    profile_id: str
    status: str
    seed: int
    started_at_utc: str
    ended_at_utc: str
    produced_output_ids: tuple[str, ...] = ()
    missing_required_output_ids: tuple[str, ...] = ()
    reason: str | None = None
    traceback: str | None = None

    def __post_init__(self) -> None:
        if self.status not in CASE_STATUSES:
            raise ValueError(f"Unknown case status: {self.status}")

    def as_dict(self) -> dict[str, Any]:
        return json_safe(asdict(self))
