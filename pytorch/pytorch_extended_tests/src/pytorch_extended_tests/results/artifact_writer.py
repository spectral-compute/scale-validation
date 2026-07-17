"""Record case outputs and move tensor payloads into the artifact tree."""

from __future__ import annotations

import hashlib
import json
import re
from collections.abc import Mapping, Sequence
from dataclasses import asdict, is_dataclass
from pathlib import Path
from typing import Any

import numpy as np

from config.suite_config import OUTPUT_CAPTURE
from config.test_catalogue import TestSpec
from pytorch_extended_tests.results.observation import ObservationRecord, json_safe
from pytorch_extended_tests.results.tensor_storage import is_tensor_like, write_tensor_artifact


_SAFE_COMPONENT = re.compile(r"[^A-Za-z0-9_.-]+")


def safe_component(value: str) -> str:
    """Make an identifier safe to use as one path component."""

    cleaned = _SAFE_COMPONENT.sub("_", value).strip("._")
    return cleaned or "unnamed"


class CaseObservationWriter:
    """Validate and store all declared outputs for one case."""

    def __init__(
        self,
        *,
        results_root: Path,
        observations_path: Path,
        test_spec: TestSpec,
        case_id: str,
        profile_id: str,
        seed: int,
    ) -> None:
        self._results_root = results_root
        self._observations_path = observations_path
        self._test_spec = test_spec
        self._case_id = case_id
        self._profile_id = profile_id
        self._seed = seed
        self._output_specs = {item.output_id: item for item in test_spec.outputs}
        self._produced_output_ids: set[str] = set()
        self._artifact_directory = (
            results_root
            / "artifacts"
            / safe_component(test_spec.level)
            / safe_component(test_spec.test_id)
            / safe_component(profile_id)
            / safe_component(case_id)
        )

    @property
    def produced_output_ids(self) -> tuple[str, ...]:
        return tuple(
            item.output_id
            for item in self._test_spec.outputs
            if item.output_id in self._produced_output_ids
        )

    def record(
        self,
        output_id: str,
        value: Any,
        *,
        coordinates: Mapping[str, Any] | None = None,
    ) -> None:
        """Store one output declared for this test."""

        try:
            output_spec = self._output_specs[output_id]
        except KeyError as exc:
            raise KeyError(
                f"{self._test_spec.test_id} did not declare output {output_id!r}"
            ) from exc
        if output_id in self._produced_output_ids:
            raise ValueError(f"Output {output_id!r} was recorded more than once")

        self._validate_top_level_kind(output_spec.kind, value)
        payload = self._store_value(value, path_parts=(output_id,))
        self._write_record(
            ObservationRecord(
                test_id=self._test_spec.test_id,
                case_id=self._case_id,
                profile_id=self._profile_id,
                output_id=output_id,
                kind=output_spec.kind,
                importance=output_spec.importance,
                status="produced",
                seed=self._seed,
                payload=payload,
                coordinates=coordinates,
            )
        )
        self._produced_output_ids.add(output_id)

    def record_skipped(self, reason: str) -> None:
        """Record every declared output as unsupported."""

        for output_spec in self._test_spec.outputs:
            if output_spec.output_id in self._produced_output_ids:
                continue
            self._write_record(
                ObservationRecord(
                    test_id=self._test_spec.test_id,
                    case_id=self._case_id,
                    profile_id=self._profile_id,
                    output_id=output_spec.output_id,
                    kind=output_spec.kind,
                    importance=output_spec.importance,
                    status="skipped_unsupported",
                    seed=self._seed,
                    reason=reason,
                )
            )

    def record_failure(self, reason: str) -> None:
        """Record outputs which were not produced after a case failure."""

        for output_spec in self._test_spec.outputs:
            if output_spec.output_id in self._produced_output_ids:
                continue
            self._write_record(
                ObservationRecord(
                    test_id=self._test_spec.test_id,
                    case_id=self._case_id,
                    profile_id=self._profile_id,
                    output_id=output_spec.output_id,
                    kind=output_spec.kind,
                    importance=output_spec.importance,
                    status="failed_to_produce",
                    seed=self._seed,
                    reason=reason,
                )
            )

    def missing_required_output_ids(self) -> tuple[str, ...]:
        return tuple(
            item.output_id
            for item in self._test_spec.outputs
            if item.importance == "required" and item.output_id not in self._produced_output_ids
        )

    def _validate_top_level_kind(self, kind: str, value: Any) -> None:
        if kind == "scalar" and not self._is_scalar(value):
            raise TypeError("Scalar outputs must contain one scalar value")
        if kind == "tensor" and not is_tensor_like(value):
            raise TypeError("Tensor outputs must contain one tensor or NumPy array")
        if kind == "exact_record" and self._contains_tensor(value):
            raise TypeError("Exact records cannot contain tensor payloads")
        if kind in {"tensor_map", "invariant_bundle"} and not isinstance(value, Mapping):
            raise TypeError(f"{kind} outputs must contain a mapping")
        if kind in {"tensor_map", "invariant_bundle"} and not self._contains_tensor(value):
            raise TypeError(f"{kind} outputs must contain at least one tensor")
        if kind == "series" and not self._is_series(value):
            raise TypeError("Series outputs must be a one-dimensional tensor or scalar sequence")

    def _store_value(self, value: Any, *, path_parts: tuple[str, ...]) -> Any:
        if is_tensor_like(value):
            relative_path = self._tensor_relative_path(path_parts)
            return write_tensor_artifact(
                value,
                destination=self._results_root / relative_path,
                relative_path=relative_path,
            )
        if is_dataclass(value) and not isinstance(value, type):
            return self._store_value(asdict(value), path_parts=path_parts)
        if isinstance(value, np.generic):
            return json_safe(value.item())
        if isinstance(value, Mapping):
            stored: dict[str, Any] = {}
            for key, item in value.items():
                if not isinstance(key, str):
                    raise TypeError("Artifact mappings must use string keys")
                stored[key] = self._store_value(item, path_parts=(*path_parts, key))
            return stored
        if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
            if len(value) > OUTPUT_CAPTURE["maximum_inline_series_length"]:
                raise ValueError("Inline output sequence exceeds the configured maximum length")
            return [
                self._store_value(item, path_parts=(*path_parts, f"item_{index:06d}"))
                for index, item in enumerate(value)
            ]
        return json_safe(value)

    def _tensor_relative_path(self, path_parts: tuple[str, ...]) -> Path:
        logical_name = "__".join(path_parts)
        readable_name = "__".join(safe_component(part) for part in path_parts)[:140]
        suffix = hashlib.sha256(logical_name.encode("utf-8")).hexdigest()[:12]
        filename = f"{readable_name}__{suffix}.bin"
        return self._artifact_directory.relative_to(self._results_root) / filename

    def _write_record(self, record: ObservationRecord) -> None:
        self._observations_path.parent.mkdir(parents=True, exist_ok=True)
        with self._observations_path.open("a", encoding="utf-8", newline="\n") as output:
            json.dump(record.as_dict(), output, sort_keys=True, allow_nan=False)
            output.write("\n")

    @staticmethod
    def _is_scalar(value: Any) -> bool:
        return isinstance(value, (bool, int, float, np.generic))

    @staticmethod
    def _contains_tensor(value: Any) -> bool:
        if is_tensor_like(value):
            return True
        if isinstance(value, Mapping):
            return any(CaseObservationWriter._contains_tensor(item) for item in value.values())
        if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
            return any(CaseObservationWriter._contains_tensor(item) for item in value)
        return False

    @staticmethod
    def _is_series(value: Any) -> bool:
        if is_tensor_like(value):
            return getattr(value, "ndim", None) == 1
        if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
            return all(CaseObservationWriter._is_scalar(item) for item in value)
        return False
