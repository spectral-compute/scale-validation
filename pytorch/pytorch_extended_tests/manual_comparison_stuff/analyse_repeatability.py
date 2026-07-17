#!/usr/bin/env python3
"""Analyse repeatability across raw suite result bundles.

The input directory should contain two or more subdirectories whose names begin
with ``repeatability_``. Each of those subdirectories must be one unmodified
result bundle produced by this repository.

The script measures observed variation first, then can optionally populate the
central comparison-policy template from the reference variability it observed.
The three top-level repeatability classifications mean:

* ``exact``: every run produced the same output structure and every stored value
  matched exactly, including tensor bytes and exceptional-value positions
* ``variable``: all outputs remained structurally comparable, but at least one
  floating-point scalar or tensor changed numerically between runs. This is an
  observation only and is not automatically a failure
* ``inconsistent``: at least one output was missing, failed to produce, changed
  structure/dtype/shape, changed an exact value, or changed its NaN/Inf masks.
  These differences cannot be treated as ordinary floating-point drift

The JSON output is deliberately more detailed than the Markdown report. It keeps
stable output identities, per-run tensor artefact references, pairwise metrics,
variability summaries and representative-run choices so a later tool can compare
one GPU/compiler environment against another without rerunning this analysis.
"""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import statistics
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

import numpy as np

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = REPOSITORY_ROOT / "src"
for import_root in (REPOSITORY_ROOT, SRC_ROOT):
    value = str(import_root)
    if value not in sys.path:
        sys.path.insert(0, value)

from config.test_catalogue import get_test_spec  # noqa: E402
from comparison_policy import (  # noqa: E402
    BUILTIN_TEMPLATE_PATH,
    load_policy_template,
    populate_policy_from_repeatability,
    write_json as write_policy_json,
)


ANALYSIS_FORMAT_VERSION = "repeatability_v1"
DEFAULT_JSON_NAME = "repeatability_analysis.json"
DEFAULT_MARKDOWN_NAME = "repeatability_analysis.md"
NUMERIC_RECORD_OUTPUT_IDS = {"summary", "final_metrics"}
PREVIEW_OUTPUT_IDS = {"loss_series", "training_loss", "checkpoint_metrics", "checkpoint_logits", "evaluation_outputs", "final_predictions"}
PREVIEW_TENSOR_VALUE_COUNT = 512
CRITICAL_MANIFEST_FIELDS = (
    "suite_name",
    "suite_version",
    "result_format_version",
    "test_catalogue_version",
    "root_seed",
    "dataset_manifest_sha256",
    "device",
    "profile_ids",
)


@dataclass(frozen=True, slots=True)
class RunBundle:
    """One raw suite result bundle used as a repeat."""

    run_id: str
    path: Path
    manifest: Mapping[str, Any]
    tasks: tuple[Mapping[str, Any], ...]
    observations: Mapping[str, Mapping[str, Any]]


@dataclass(frozen=True, slots=True)
class LeafValue:
    """One recursively flattened value from an observation payload."""

    path: str
    value_type: str
    value: Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input_directory",
        nargs="?",
        type=Path,
        default=Path.cwd(),
        help="Directory containing repeatability_* result-bundle subdirectories",
    )
    parser.add_argument(
        "--output-directory",
        type=Path,
        help="Output directory, defaulting to <input>/repeatability_analysis",
    )
    parser.add_argument(
        "--pattern",
        default="repeatability_*",
        help="Glob used to locate result-bundle directories",
    )
    parser.add_argument(
        "--skip-artifact-hash-check",
        action="store_true",
        help="Trust tensor descriptor hashes instead of recalculating them",
    )
    parser.add_argument(
        "--no-plots",
        action="store_true",
        help="Do not produce the Matplotlib PNG summaries",
    )
    parser.add_argument(
        "--top-output-count",
        type=int,
        default=30,
        help="Maximum number of variable outputs shown in the detailed Markdown table",
    )
    parser.add_argument(
        "--write-populated-policy",
        nargs="?",
        const="comparison_policy.json",
        help=(
            "Populate the comparison policy from this repeatability analysis. "
            "With no path, writes comparison_policy.json in the analysis output directory"
        ),
    )
    parser.add_argument(
        "--policy-template",
        type=Path,
        default=BUILTIN_TEMPLATE_PATH,
        help="Comparison-policy template used with --write-populated-policy",
    )
    return parser.parse_args()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RuntimeError(f"Required file is missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"File is not valid JSON: {path}") from exc


def read_json_lines(path: Path) -> list[dict[str, Any]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError as exc:
        raise RuntimeError(f"Required file is missing: {path}") from exc

    records: list[dict[str, Any]] = []
    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"Invalid JSON on {path}:{line_number}") from exc
        if not isinstance(value, dict):
            raise RuntimeError(f"Observation on {path}:{line_number} is not an object")
        records.append(value)
    return records


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def observation_identity(record: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "test_id": str(record.get("test_id")),
        "case_id": str(record.get("case_id")),
        "profile_id": str(record.get("profile_id")),
        "output_id": str(record.get("output_id")),
        "coordinates": record.get("coordinates"),
    }


def observation_key(record: Mapping[str, Any]) -> str:
    return canonical_json(observation_identity(record))


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def discover_run_directories(input_directory: Path, pattern: str) -> list[Path]:
    candidates = []
    for path in sorted(input_directory.glob(pattern), key=lambda item: item.name):
        if not path.is_dir():
            continue
        if not (path / "run_manifest.json").is_file():
            continue
        if not (path / "observations.jsonl").is_file():
            continue
        if not (path / "test_status.json").is_file():
            continue
        candidates.append(path)
    if len(candidates) < 2:
        raise RuntimeError(
            f"Expected at least two valid {pattern!r} result directories beneath "
            f"{input_directory}, found {len(candidates)}"
        )
    return candidates


def load_run_bundle(path: Path) -> RunBundle:
    manifest = read_json(path / "run_manifest.json")
    status = read_json(path / "test_status.json")
    tasks = status.get("tasks") if isinstance(status, Mapping) else None
    if not isinstance(tasks, list):
        raise RuntimeError(f"test_status.json has no tasks list: {path}")

    observations: dict[str, Mapping[str, Any]] = {}
    for record in read_json_lines(path / "observations.jsonl"):
        key = observation_key(record)
        if key in observations:
            raise RuntimeError(f"Duplicate observation identity in {path.name}: {key}")
        observations[key] = record

    return RunBundle(
        run_id=path.name,
        path=path,
        manifest=manifest,
        tasks=tuple(tasks),
        observations=observations,
    )


def compatibility_summary(runs: Sequence[RunBundle]) -> dict[str, Any]:
    fields: dict[str, Any] = {}
    mismatches: list[str] = []
    for field in CRITICAL_MANIFEST_FIELDS:
        values = {run.run_id: run.manifest.get(field) for run in runs}
        encoded = {canonical_json(value) for value in values.values()}
        matches = len(encoded) == 1
        fields[field] = {
            "matches": matches,
            "common_value": next(iter(values.values())) if matches else None,
            "values_by_run": values,
        }
        if not matches:
            mismatches.append(field)
    return {
        "status": "compatible" if not mismatches else "incompatible",
        "mismatched_fields": mismatches,
        "fields": fields,
    }


def validate_compatibility(summary: Mapping[str, Any]) -> None:
    mismatches = summary.get("mismatched_fields")
    if mismatches:
        raise RuntimeError(
            "The repeatability bundles are not directly comparable. "
            "Mismatched manifest fields: " + ", ".join(str(item) for item in mismatches)
        )


def is_tensor_descriptor(value: Any) -> bool:
    return isinstance(value, Mapping) and value.get("artifact_type") == "tensor"


def is_special_float(value: Any) -> bool:
    return (
        isinstance(value, Mapping)
        and value.get("value_type") == "special_float"
        and isinstance(value.get("value"), str)
    )


def pointer_component(value: str) -> str:
    return value.replace("~", "~0").replace("/", "~1")


def flatten_payload(
    value: Any,
    *,
    path: str = "",
    numeric_scalars: bool = True,
) -> list[LeafValue]:
    if is_tensor_descriptor(value):
        return [LeafValue(path or "/", "tensor", value)]
    if is_special_float(value):
        return [LeafValue(path or "/", "special_float", value)]
    if isinstance(value, Mapping):
        leaves: list[LeafValue] = []
        for key in sorted(value):
            child_path = f"{path}/{pointer_component(str(key))}"
            leaves.extend(
                flatten_payload(
                    value[key],
                    path=child_path,
                    numeric_scalars=numeric_scalars,
                )
            )
        if not leaves:
            leaves.append(LeafValue(path or "/", "exact_value", {}))
        return leaves
    if isinstance(value, list):
        leaves = []
        for index, item in enumerate(value):
            leaves.extend(
                flatten_payload(
                    item,
                    path=f"{path}/{index}",
                    numeric_scalars=numeric_scalars,
                )
            )
        if not leaves:
            leaves.append(LeafValue(path or "/", "exact_value", []))
        return leaves
    if isinstance(value, bool) or value is None or isinstance(value, str):
        return [LeafValue(path or "/", "exact_value", value)]
    if isinstance(value, int):
        return [LeafValue(path or "/", "exact_value", value)]
    if isinstance(value, float):
        value_type = "numeric_scalar" if numeric_scalars else "exact_value"
        return [LeafValue(path or "/", value_type, value)]
    return [LeafValue(path or "/", "exact_value", value)]


def descriptor_summary(descriptor: Mapping[str, Any]) -> dict[str, Any]:
    fields = (
        "relative_path",
        "sha256",
        "byte_length",
        "logical_dtype",
        "storage_dtype",
        "shape",
        "numel",
        "finite_count",
        "nan_count",
        "infinity_count",
        "positive_infinity_count",
        "negative_infinity_count",
    )
    return {field: descriptor.get(field) for field in fields}


def _bfloat16_to_float32(values: np.ndarray) -> np.ndarray:
    words = values.astype(np.uint32, copy=False) << np.uint32(16)
    return words.view(np.float32)


def validate_tensor_artifact_file(
    run: RunBundle,
    descriptor: Mapping[str, Any],
    *,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> Path:
    relative_path = descriptor.get("relative_path")
    if not isinstance(relative_path, str):
        raise RuntimeError(f"Tensor descriptor in {run.run_id} has no relative_path")
    path = run.path / relative_path
    if not path.is_file():
        raise RuntimeError(f"Tensor artefact is missing: {path}")

    expected_length = descriptor.get("byte_length")
    if not isinstance(expected_length, int) or path.stat().st_size != expected_length:
        raise RuntimeError(f"Tensor artefact size does not match its descriptor: {path}")

    cache_key = (run.path.as_posix(), relative_path)
    if verify_hash and cache_key not in verified_paths:
        expected_hash = descriptor.get("sha256")
        if not isinstance(expected_hash, str) or hash_file(path) != expected_hash:
            raise RuntimeError(f"Tensor artefact hash does not match: {path}")
        verified_paths.add(cache_key)
    return path


def load_tensor(
    run: RunBundle,
    descriptor: Mapping[str, Any],
    *,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> np.ndarray:
    path = validate_tensor_artifact_file(
        run,
        descriptor,
        verify_hash=verify_hash,
        verified_paths=verified_paths,
    )

    storage_dtype = descriptor.get("storage_dtype")
    logical_dtype = descriptor.get("logical_dtype")
    shape = descriptor.get("shape")
    numel = descriptor.get("numel")
    if not isinstance(storage_dtype, str) or not isinstance(shape, list) or not isinstance(numel, int):
        raise RuntimeError(f"Tensor descriptor is incomplete: {path}")

    stored = np.fromfile(path, dtype=np.dtype(storage_dtype), count=numel)
    if stored.size != numel:
        raise RuntimeError(f"Tensor artefact has the wrong element count: {path}")
    if logical_dtype == "bfloat16":
        values = _bfloat16_to_float32(stored.astype(np.uint16, copy=False))
    else:
        values = stored
    return values.reshape(tuple(int(item) for item in shape))


def _safe_float(value: float | np.floating[Any]) -> float | None:
    converted = float(value)
    return converted if math.isfinite(converted) else None


def _percentile(values: Sequence[float], percentile: float) -> float | None:
    if not values:
        return None
    return _safe_float(np.percentile(np.asarray(values, dtype=np.float64), percentile))


def numeric_pair_metrics(left: np.ndarray, right: np.ndarray) -> dict[str, Any]:
    if left.shape != right.shape:
        return {
            "comparable": False,
            "reason": "shape_mismatch",
            "left_shape": list(left.shape),
            "right_shape": list(right.shape),
        }

    left_values = np.asarray(left)
    right_values = np.asarray(right)
    left_nan = np.isnan(left_values) if np.issubdtype(left_values.dtype, np.inexact) else np.zeros(left.shape, dtype=bool)
    right_nan = np.isnan(right_values) if np.issubdtype(right_values.dtype, np.inexact) else np.zeros(right.shape, dtype=bool)
    left_inf = np.isinf(left_values) if np.issubdtype(left_values.dtype, np.inexact) else np.zeros(left.shape, dtype=bool)
    right_inf = np.isinf(right_values) if np.issubdtype(right_values.dtype, np.inexact) else np.zeros(right.shape, dtype=bool)
    left_finite = ~(left_nan | left_inf)
    right_finite = ~(right_nan | right_inf)
    jointly_finite = left_finite & right_finite

    nan_mask_mismatch = int(np.count_nonzero(left_nan != right_nan))
    infinity_mask_mismatch = int(np.count_nonzero(left_inf != right_inf))
    finite_mask_mismatch = int(np.count_nonzero(left_finite != right_finite))

    exact_mask = left_values == right_values
    exact_mask = exact_mask | (left_nan & right_nan)
    mismatch_count = int(left_values.size - np.count_nonzero(exact_mask))

    metrics: dict[str, Any] = {
        "comparable": True,
        "element_count": int(left_values.size),
        "exact_equal": mismatch_count == 0,
        "mismatch_count": mismatch_count,
        "mismatch_fraction": mismatch_count / left_values.size if left_values.size else 0.0,
        "nan_mask_mismatch_count": nan_mask_mismatch,
        "infinity_mask_mismatch_count": infinity_mask_mismatch,
        "finite_mask_mismatch_count": finite_mask_mismatch,
        "jointly_finite_count": int(np.count_nonzero(jointly_finite)),
    }

    if not np.any(jointly_finite):
        metrics.update(
            {
                "maximum_absolute_error": None,
                "mean_absolute_error": None,
                "root_mean_square_error": None,
                "normalised_root_mean_square_error": None,
                "relative_l2_error": None,
                "maximum_symmetric_relative_error": None,
            }
        )
        return metrics

    left_f = left_values[jointly_finite].astype(np.complex128 if np.iscomplexobj(left_values) else np.float64)
    right_f = right_values[jointly_finite].astype(np.complex128 if np.iscomplexobj(right_values) else np.float64)
    absolute_error = np.abs(left_f - right_f).astype(np.float64)
    left_abs = np.abs(left_f).astype(np.float64)
    right_abs = np.abs(right_f).astype(np.float64)

    difference_l2 = float(np.linalg.norm(absolute_error.ravel(), ord=2))
    left_l2 = float(np.linalg.norm(left_abs.ravel(), ord=2))
    right_l2 = float(np.linalg.norm(right_abs.ravel(), ord=2))
    relative_l2 = difference_l2 / max(left_l2, right_l2, np.finfo(np.float64).tiny)

    rmse = float(np.sqrt(np.mean(np.square(absolute_error, dtype=np.float64))))
    left_rms = float(np.sqrt(np.mean(np.square(left_abs, dtype=np.float64))))
    right_rms = float(np.sqrt(np.mean(np.square(right_abs, dtype=np.float64))))
    normalised_rmse = rmse / max(left_rms, right_rms, np.finfo(np.float64).tiny)

    symmetric_denominator = np.maximum(
        np.maximum(left_abs, right_abs),
        np.finfo(np.float64).tiny,
    )
    symmetric_relative = absolute_error / symmetric_denominator
    metrics.update(
        {
            "maximum_absolute_error": _safe_float(np.max(absolute_error)),
            "mean_absolute_error": _safe_float(np.mean(absolute_error)),
            "root_mean_square_error": _safe_float(rmse),
            "normalised_root_mean_square_error": _safe_float(normalised_rmse),
            "relative_l2_error": _safe_float(relative_l2),
            "maximum_symmetric_relative_error": _safe_float(np.max(symmetric_relative)),
        }
    )
    return metrics


def tensor_pair_metrics(
    left_run: RunBundle,
    left_descriptor: Mapping[str, Any],
    right_run: RunBundle,
    right_descriptor: Mapping[str, Any],
    *,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> dict[str, Any]:
    metadata_fields = ("logical_dtype", "shape", "numel")
    metadata_matches = all(left_descriptor.get(field) == right_descriptor.get(field) for field in metadata_fields)
    result: dict[str, Any] = {
        "run_a": left_run.run_id,
        "run_b": right_run.run_id,
        "metadata_matches": metadata_matches,
        "sha256_matches": left_descriptor.get("sha256") == right_descriptor.get("sha256"),
    }
    if not metadata_matches:
        result.update(
            {
                "comparable": False,
                "reason": "tensor_metadata_mismatch",
                "left": descriptor_summary(left_descriptor),
                "right": descriptor_summary(right_descriptor),
            }
        )
        return result

    validate_tensor_artifact_file(
        left_run,
        left_descriptor,
        verify_hash=verify_hash,
        verified_paths=verified_paths,
    )
    validate_tensor_artifact_file(
        right_run,
        right_descriptor,
        verify_hash=verify_hash,
        verified_paths=verified_paths,
    )

    if result["sha256_matches"]:
        result.update(
            {
                "comparable": True,
                "element_count": int(left_descriptor.get("numel", 0)),
                "exact_equal": True,
                "mismatch_count": 0,
                "mismatch_fraction": 0.0,
                "nan_mask_mismatch_count": 0,
                "infinity_mask_mismatch_count": 0,
                "finite_mask_mismatch_count": 0,
                "jointly_finite_count": int(left_descriptor.get("finite_count", 0)),
                "maximum_absolute_error": 0.0,
                "mean_absolute_error": 0.0,
                "root_mean_square_error": 0.0,
                "normalised_root_mean_square_error": 0.0,
                "relative_l2_error": 0.0,
                "maximum_symmetric_relative_error": 0.0,
            }
        )
        return result

    left = load_tensor(
        left_run,
        left_descriptor,
        verify_hash=verify_hash,
        verified_paths=verified_paths,
    )
    right = load_tensor(
        right_run,
        right_descriptor,
        verify_hash=verify_hash,
        verified_paths=verified_paths,
    )
    result.update(numeric_pair_metrics(left, right))
    return result


def scalar_pair_metrics(left: Any, right: Any, *, run_a: str, run_b: str) -> dict[str, Any]:
    left_array = np.asarray([left])
    right_array = np.asarray([right])
    result = {"run_a": run_a, "run_b": run_b}
    result.update(numeric_pair_metrics(left_array, right_array))
    return result


def exact_pair_result(left: Any, right: Any, *, run_a: str, run_b: str) -> dict[str, Any]:
    return {
        "run_a": run_a,
        "run_b": run_b,
        "comparable": True,
        "exact_equal": canonical_json(left) == canonical_json(right),
    }


def pair_numeric_distance(pair: Mapping[str, Any]) -> float | None:
    value = pair.get("relative_l2_error")
    if isinstance(value, (int, float)) and math.isfinite(float(value)):
        return float(value)
    value = pair.get("normalised_root_mean_square_error")
    if isinstance(value, (int, float)) and math.isfinite(float(value)):
        return float(value)
    return None


def summarise_pairwise(pairwise: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    exact_pair_count = sum(bool(pair.get("exact_equal")) for pair in pairwise)
    comparable_pair_count = sum(bool(pair.get("comparable")) for pair in pairwise)
    numeric_distances = [
        value
        for pair in pairwise
        if (value := pair_numeric_distance(pair)) is not None
    ]
    absolute_errors = [
        float(value)
        for pair in pairwise
        if isinstance((value := pair.get("maximum_absolute_error")), (int, float))
        and math.isfinite(float(value))
    ]
    mismatch_fractions = [
        float(value)
        for pair in pairwise
        if isinstance((value := pair.get("mismatch_fraction")), (int, float))
        and math.isfinite(float(value))
    ]

    worst_pair = None
    if pairwise:
        def ranking(pair: Mapping[str, Any]) -> tuple[int, int, float, float]:
            structural = 0 if pair.get("comparable") else 1
            exact_mismatch = 0 if pair.get("exact_equal") else 1
            numeric = pair_numeric_distance(pair) or 0.0
            absolute = float(pair.get("maximum_absolute_error") or 0.0)
            return structural, exact_mismatch, numeric, absolute

        worst_pair = dict(max(pairwise, key=ranking))

    return {
        "pair_count": len(pairwise),
        "comparable_pair_count": comparable_pair_count,
        "exact_pair_count": exact_pair_count,
        "exact_pair_fraction": exact_pair_count / len(pairwise) if pairwise else None,
        "maximum_relative_l2_error": max(numeric_distances, default=None),
        "median_relative_l2_error": statistics.median(numeric_distances) if numeric_distances else None,
        "p95_relative_l2_error": _percentile(numeric_distances, 95.0),
        "maximum_absolute_error": max(absolute_errors, default=None),
        "maximum_mismatch_fraction": max(mismatch_fractions, default=None),
        "worst_pair": worst_pair,
    }


def classify_leaf(
    *,
    run_count: int,
    available_count: int,
    value_type: str,
    pairwise: Sequence[Mapping[str, Any]],
) -> str:
    if available_count != run_count:
        return "missing_runs"
    if any(not pair.get("comparable", False) for pair in pairwise):
        return "structural_mismatch"
    if all(pair.get("exact_equal", False) for pair in pairwise):
        return "exact"
    if value_type in {"tensor", "numeric_scalar"}:
        if any(
            int(pair.get("finite_mask_mismatch_count", 0)) > 0
            or int(pair.get("nan_mask_mismatch_count", 0)) > 0
            or int(pair.get("infinity_mask_mismatch_count", 0)) > 0
            for pair in pairwise
        ):
            return "exceptional_value_mismatch"
        return "numeric_variation"
    return "exact_value_mismatch"


def leaf_distance(pair: Mapping[str, Any], value_type: str) -> float:
    if not pair.get("comparable", False):
        return 1_000_000.0
    if pair.get("exact_equal", False):
        return 0.0
    if value_type in {"tensor", "numeric_scalar"}:
        numeric = pair_numeric_distance(pair)
        if numeric is not None:
            return math.log1p(max(numeric, 0.0))
        return 10.0
    return 1.0


def medoid_run(run_ids: Sequence[str], pair_distances: Mapping[tuple[str, str], float]) -> str | None:
    if not run_ids:
        return None
    if len(run_ids) == 1:
        return run_ids[0]
    scores: dict[str, float] = {}
    for run_id in run_ids:
        score = 0.0
        for other in run_ids:
            if other == run_id:
                continue
            key = tuple(sorted((run_id, other)))
            score += float(pair_distances.get(key, 1_000_000.0))
        scores[run_id] = score
    return min(run_ids, key=lambda item: (scores[item], item))


def analyse_leaf(
    *,
    path: str,
    values_by_run: Mapping[str, LeafValue],
    runs_by_id: Mapping[str, RunBundle],
    all_run_ids: Sequence[str],
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> dict[str, Any]:
    value_types = sorted({leaf.value_type for leaf in values_by_run.values()})
    value_type = value_types[0] if len(value_types) == 1 else "mixed"
    pairwise: list[dict[str, Any]] = []
    pair_distances: dict[tuple[str, str], float] = {}

    for run_a, run_b in itertools.combinations(sorted(values_by_run), 2):
        left = values_by_run[run_a]
        right = values_by_run[run_b]
        if left.value_type != right.value_type:
            pair = {
                "run_a": run_a,
                "run_b": run_b,
                "comparable": False,
                "exact_equal": False,
                "reason": "value_type_mismatch",
                "left_value_type": left.value_type,
                "right_value_type": right.value_type,
            }
        elif left.value_type == "tensor":
            pair = tensor_pair_metrics(
                runs_by_id[run_a],
                left.value,
                runs_by_id[run_b],
                right.value,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
            )
        elif left.value_type == "numeric_scalar":
            pair = scalar_pair_metrics(left.value, right.value, run_a=run_a, run_b=run_b)
        else:
            pair = exact_pair_result(left.value, right.value, run_a=run_a, run_b=run_b)
        pairwise.append(pair)
        pair_distances[tuple(sorted((run_a, run_b)))] = leaf_distance(pair, left.value_type)

    run_values: dict[str, Any] = {}
    for run_id, leaf in sorted(values_by_run.items()):
        if leaf.value_type == "tensor":
            run_values[run_id] = descriptor_summary(leaf.value)
        else:
            run_values[run_id] = leaf.value

    status = classify_leaf(
        run_count=len(all_run_ids),
        available_count=len(values_by_run),
        value_type=value_type,
        pairwise=pairwise,
    )
    return {
        "path": path,
        "value_type": value_type,
        "status": status,
        "available_runs": sorted(values_by_run),
        "missing_runs": sorted(set(all_run_ids) - set(values_by_run)),
        "representative_run": medoid_run(sorted(values_by_run), pair_distances),
        "runs": run_values,
        "pairwise": pairwise,
        "summary": summarise_pairwise(pairwise),
    }




def _json_numeric(value: Any) -> Any:
    """Convert one NumPy scalar into ordinary JSON data."""

    converted = np.asarray(value).item()
    if isinstance(converted, complex):
        return {"real": float(converted.real), "imag": float(converted.imag)}
    if isinstance(converted, (np.bool_, bool)):
        return bool(converted)
    if isinstance(converted, (np.integer, int)):
        return int(converted)
    if isinstance(converted, (np.floating, float)):
        numeric = float(converted)
        return numeric if math.isfinite(numeric) else None
    return converted


def _tensor_preview(array: np.ndarray, descriptor: Mapping[str, Any]) -> dict[str, Any]:
    """Keep a compact numeric preview without turning analysis JSON into another artefact bundle."""

    values = np.asarray(array)
    flattened = values.reshape(-1)
    sample_count = min(flattened.size, PREVIEW_TENSOR_VALUE_COUNT)
    if sample_count:
        sample_indices = np.linspace(0, flattened.size - 1, sample_count, dtype=np.int64)
        sample_values = [_json_numeric(flattened[index]) for index in sample_indices]
    else:
        sample_indices = np.asarray([], dtype=np.int64)
        sample_values = []
    finite = np.isfinite(values) if np.issubdtype(values.dtype, np.inexact) else np.ones(values.shape, dtype=bool)
    finite_values = values[finite]
    if np.iscomplexobj(finite_values):
        summary_values = np.abs(finite_values).astype(np.float64)
    else:
        summary_values = finite_values.astype(np.float64, copy=False)
    return {
        "logical_dtype": descriptor.get("logical_dtype"),
        "shape": list(values.shape),
        "numel": int(values.size),
        "sample_indices": sample_indices.tolist(),
        "sample_values": sample_values,
        "mean": float(np.mean(summary_values)) if summary_values.size else None,
        "standard_deviation": float(np.std(summary_values)) if summary_values.size else None,
        "minimum": float(np.min(summary_values)) if summary_values.size else None,
        "maximum": float(np.max(summary_values)) if summary_values.size else None,
        "l2_norm": float(np.linalg.norm(summary_values.reshape(-1), 2)) if summary_values.size else 0.0,
    }


def build_representative_preview(
    value: Any,
    *,
    output_id: str,
    run: RunBundle,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> Any:
    """Load just enough representative data for the lightweight comparison plots."""

    if is_tensor_descriptor(value):
        array = load_tensor(
            run,
            value,
            verify_hash=verify_hash,
            verified_paths=verified_paths,
        )
        if array.size == 1:
            return _json_numeric(array.reshape(-1)[0])
        if output_id in {"checkpoint_logits", "evaluation_outputs", "final_predictions"}:
            return _tensor_preview(array, value)
        return descriptor_summary(value)
    if isinstance(value, Mapping):
        return {
            str(key): build_representative_preview(
                item,
                output_id=output_id,
                run=run,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
            )
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [
            build_representative_preview(
                item,
                output_id=output_id,
                run=run,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
            )
            for item in value
        ]
    return value

def output_pair_distances(
    leaves: Sequence[Mapping[str, Any]],
    run_ids: Sequence[str],
) -> tuple[list[dict[str, Any]], dict[tuple[str, str], float]]:
    output_pairs: list[dict[str, Any]] = []
    distances: dict[tuple[str, str], float] = {}
    for run_a, run_b in itertools.combinations(sorted(run_ids), 2):
        leaf_distances: list[float] = []
        structural_mismatch_count = 0
        exact_value_mismatch_count = 0
        numeric_values: list[float] = []
        compared_leaf_count = 0
        for leaf in leaves:
            pair = next(
                (
                    item
                    for item in leaf.get("pairwise", [])
                    if {item.get("run_a"), item.get("run_b")} == {run_a, run_b}
                ),
                None,
            )
            if pair is None:
                structural_mismatch_count += 1
                leaf_distances.append(1_000_000.0)
                continue
            compared_leaf_count += 1
            if not pair.get("comparable", False):
                structural_mismatch_count += 1
            elif not pair.get("exact_equal", False) and leaf.get("value_type") not in {
                "tensor",
                "numeric_scalar",
            }:
                exact_value_mismatch_count += 1
            value = pair_numeric_distance(pair)
            if value is not None:
                numeric_values.append(value)
            leaf_distances.append(leaf_distance(pair, str(leaf.get("value_type"))))

        distance = max(leaf_distances, default=0.0)
        distances[(run_a, run_b)] = distance
        output_pairs.append(
            {
                "run_a": run_a,
                "run_b": run_b,
                "compared_leaf_count": compared_leaf_count,
                "structural_mismatch_count": structural_mismatch_count,
                "exact_value_mismatch_count": exact_value_mismatch_count,
                "maximum_relative_l2_error": max(numeric_values, default=None),
                "median_relative_l2_error": statistics.median(numeric_values) if numeric_values else None,
                "distance_score": distance,
            }
        )
    return output_pairs, distances


def classify_output(run_count: int, records_by_run: Mapping[str, Mapping[str, Any]], leaves: Sequence[Mapping[str, Any]]) -> str:
    # exact means the structure and all stored values match exactly across every run
    # numeric_variation means only ordinary numeric values changed and remain comparable
    # every other result is inconsistent because it involves missing data, structure or exact values
    if len(records_by_run) != run_count:
        return "missing_runs"
    statuses = {str(record.get("status")) for record in records_by_run.values()}
    if statuses == {"skipped_unsupported"}:
        return "skipped_unsupported"
    if statuses == {"failed_to_produce"}:
        return "failed_to_produce"
    if statuses != {"produced"}:
        return "not_produced_consistently"
    leaf_statuses = {str(leaf.get("status")) for leaf in leaves}
    if leaf_statuses <= {"exact"}:
        return "exact"
    if leaf_statuses <= {"exact", "numeric_variation"}:
        return "numeric_variation"
    if "structural_mismatch" in leaf_statuses:
        return "structural_mismatch"
    if "missing_runs" in leaf_statuses:
        return "missing_runs"
    if "exceptional_value_mismatch" in leaf_statuses:
        return "exceptional_value_mismatch"
    return "value_mismatch"


def analyse_output(
    key: str,
    *,
    records_by_run: Mapping[str, Mapping[str, Any]],
    runs_by_id: Mapping[str, RunBundle],
    all_run_ids: Sequence[str],
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> dict[str, Any]:
    first_record = next(iter(records_by_run.values()))
    identity = observation_identity(first_record)
    try:
        test_spec = get_test_spec(identity["test_id"])
        level = test_spec.level
        category = test_spec.category
    except KeyError:
        level = "unknown"
        category = "Unknown"

    flattened_by_run: dict[str, dict[str, LeafValue]] = {}
    for run_id, record in records_by_run.items():
        if record.get("status") != "produced":
            continue
        flattened = flatten_payload(
            record.get("payload"),
            numeric_scalars=(
                record.get("kind") in {"scalar", "series"}
                or record.get("output_id") in NUMERIC_RECORD_OUTPUT_IDS
            ),
        )
        flattened_by_run[run_id] = {leaf.path: leaf for leaf in flattened}

    all_paths = sorted({path for leaves in flattened_by_run.values() for path in leaves})
    leaves: list[dict[str, Any]] = []
    for path in all_paths:
        values_by_run = {
            run_id: flattened[path]
            for run_id, flattened in flattened_by_run.items()
            if path in flattened
        }
        leaves.append(
            analyse_leaf(
                path=path,
                values_by_run=values_by_run,
                runs_by_id=runs_by_id,
                all_run_ids=all_run_ids,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
            )
        )

    output_pairs, distances = output_pair_distances(leaves, sorted(records_by_run))
    representative_run = medoid_run(sorted(records_by_run), distances)
    representative_preview = None
    if (
        representative_run is not None
        and identity["output_id"] in PREVIEW_OUTPUT_IDS
        and records_by_run[representative_run].get("status") == "produced"
    ):
        representative_preview = build_representative_preview(
            records_by_run[representative_run].get("payload"),
            output_id=identity["output_id"],
            run=runs_by_id[representative_run],
            verify_hash=verify_hash,
            verified_paths=verified_paths,
        )
    status = classify_output(len(all_run_ids), records_by_run, leaves)
    leaf_counts = Counter(str(leaf.get("status")) for leaf in leaves)
    relative_l2_values = [
        float(value)
        for leaf in leaves
        if isinstance(
            (value := leaf.get("summary", {}).get("maximum_relative_l2_error")),
            (int, float),
        )
        and math.isfinite(float(value))
    ]
    absolute_values = [
        float(value)
        for leaf in leaves
        if isinstance(
            (value := leaf.get("summary", {}).get("maximum_absolute_error")),
            (int, float),
        )
        and math.isfinite(float(value))
    ]

    return {
        "identity_key": key,
        "identity": identity,
        "level": level,
        "category": category,
        "kind": first_record.get("kind"),
        "importance": first_record.get("importance"),
        "status": status,
        "available_runs": sorted(records_by_run),
        "missing_runs": sorted(set(all_run_ids) - set(records_by_run)),
        "run_observation_statuses": {
            run_id: record.get("status") for run_id, record in sorted(records_by_run.items())
        },
        "run_observations": {
            run_id: {
                "status": record.get("status"),
                "reason": record.get("reason"),
                "seed": record.get("seed"),
                "kind": record.get("kind"),
                "importance": record.get("importance"),
            }
            for run_id, record in sorted(records_by_run.items())
        },
        "representative_run": representative_run,
        "representative_preview": representative_preview,
        "leaf_status_counts": dict(sorted(leaf_counts.items())),
        "maximum_relative_l2_error": max(relative_l2_values, default=None),
        "maximum_absolute_error": max(absolute_values, default=None),
        "pairwise_output_distances": output_pairs,
        "leaves": leaves,
    }


def run_summary(run: RunBundle, input_root: Path) -> dict[str, Any]:
    task_statuses = Counter(str(task.get("status", "unknown")) for task in run.tasks)
    observation_statuses = Counter(
        str(record.get("status", "unknown")) for record in run.observations.values()
    )
    return {
        "run_id": run.run_id,
        "bundle_relative_path": run.path.relative_to(input_root).as_posix(),
        "overall_execution_status": run.manifest.get("overall_execution_status"),
        "planned_task_count": run.manifest.get("planned_task_count"),
        "task_count": len(run.tasks),
        "task_status_counts": dict(sorted(task_statuses.items())),
        "observation_count": len(run.observations),
        "observation_status_counts": dict(sorted(observation_statuses.items())),
        "started_at_utc": run.manifest.get("started_at_utc"),
        "ended_at_utc": run.manifest.get("ended_at_utc"),
    }


def aggregate_environment_pairs(outputs: Sequence[Mapping[str, Any]], run_ids: Sequence[str]) -> tuple[list[dict[str, Any]], str | None]:
    pairs: list[dict[str, Any]] = []
    medoid_distances: dict[tuple[str, str], float] = {}
    for run_a, run_b in itertools.combinations(sorted(run_ids), 2):
        structural = 0
        exact_mismatches = 0
        numeric_values: list[float] = []
        compared_outputs = 0
        distance_values: list[float] = []
        for output in outputs:
            pair = next(
                (
                    item
                    for item in output.get("pairwise_output_distances", [])
                    if {item.get("run_a"), item.get("run_b")} == {run_a, run_b}
                ),
                None,
            )
            if pair is None:
                structural += 1
                distance_values.append(1_000_000.0)
                continue
            compared_outputs += 1
            structural += int(pair.get("structural_mismatch_count", 0))
            exact_mismatches += int(pair.get("exact_value_mismatch_count", 0))
            numeric = pair.get("maximum_relative_l2_error")
            if isinstance(numeric, (int, float)) and math.isfinite(float(numeric)):
                numeric_values.append(float(numeric))
            distance_values.append(float(pair.get("distance_score", 0.0)))

        aggregate_distance = max(distance_values, default=0.0)
        medoid_distances[(run_a, run_b)] = aggregate_distance
        pairs.append(
            {
                "run_a": run_a,
                "run_b": run_b,
                "compared_output_count": compared_outputs,
                "structural_mismatch_count": structural,
                "exact_value_mismatch_count": exact_mismatches,
                "maximum_relative_l2_error": max(numeric_values, default=None),
                "median_relative_l2_error": statistics.median(numeric_values) if numeric_values else None,
                "p95_relative_l2_error": _percentile(numeric_values, 95.0),
                "distance_score": aggregate_distance,
            }
        )
    return pairs, medoid_run(sorted(run_ids), medoid_distances)


def build_analysis(
    runs: Sequence[RunBundle],
    *,
    input_root: Path,
    verify_hash: bool,
) -> dict[str, Any]:
    compatibility = compatibility_summary(runs)
    validate_compatibility(compatibility)

    runs_by_id = {run.run_id: run for run in runs}
    run_ids = sorted(runs_by_id)
    all_keys = sorted({key for run in runs for key in run.observations})
    verified_paths: set[tuple[str, str]] = set()
    outputs = []
    for key in all_keys:
        records_by_run = {
            run.run_id: run.observations[key]
            for run in runs
            if key in run.observations
        }
        outputs.append(
            analyse_output(
                key,
                records_by_run=records_by_run,
                runs_by_id=runs_by_id,
                all_run_ids=run_ids,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
            )
        )

    output_status_counts = Counter(str(output.get("status")) for output in outputs)
    leaf_status_counts = Counter(
        str(leaf.get("status"))
        for output in outputs
        for leaf in output.get("leaves", [])
    )
    environment_pairs, representative_run = aggregate_environment_pairs(outputs, run_ids)

    category_counts: dict[str, Counter[str]] = defaultdict(Counter)
    profile_counts: dict[str, Counter[str]] = defaultdict(Counter)
    for output in outputs:
        category_counts[str(output.get("category"))][str(output.get("status"))] += 1
        identity = output.get("identity", {})
        profile_counts[str(identity.get("profile_id"))][str(output.get("status"))] += 1

    inconsistent_statuses = {
        "missing_runs",
        "not_produced_consistently",
        "failed_to_produce",
        "structural_mismatch",
        "exceptional_value_mismatch",
        "value_mismatch",
    }
    overall_classification = (
        "inconsistent"
        if any(status in inconsistent_statuses for status in output_status_counts)
        else "variable"
        if output_status_counts.get("numeric_variation", 0)
        else "exact"
    )

    return {
        "analysis_format_version": ANALYSIS_FORMAT_VERSION,
        "analysis_kind": "intra_environment_repeatability",
        "generated_at_utc": utc_now(),
        "input_root": input_root.as_posix(),
        "run_count": len(runs),
        "run_order": run_ids,
        "overall_classification": overall_classification,
        "classification_note": (
            "This is an observed-variation classification, not a policy-based PASS or FAIL"
        ),
        "compatibility": compatibility,
        "runs": [run_summary(runs_by_id[run_id], input_root) for run_id in run_ids],
        "environment_representative_run": representative_run,
        "environment_pairwise_distances": environment_pairs,
        "summary": {
            "output_count": len(outputs),
            "output_status_counts": dict(sorted(output_status_counts.items())),
            "leaf_status_counts": dict(sorted(leaf_status_counts.items())),
            "category_status_counts": {
                category: dict(sorted(counts.items()))
                for category, counts in sorted(category_counts.items())
            },
            "profile_status_counts": {
                profile: dict(sorted(counts.items()))
                for profile, counts in sorted(profile_counts.items())
            },
            "verified_tensor_artifact_count": len(verified_paths) if verify_hash else None,
            "artifact_hashes_verified": verify_hash,
        },
        "outputs": outputs,
        "plots": [],
    }


def format_number(value: Any) -> str:
    if value is None:
        return "—"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if value == 0.0:
            return "0"
        if abs(value) >= 1000 or abs(value) < 0.001:
            return f"{value:.3e}"
        return f"{value:.6g}"
    return str(value)


def markdown_escape(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def write_markdown(
    analysis: Mapping[str, Any],
    path: Path,
    *,
    plot_paths: Sequence[Path],
    top_output_count: int,
) -> None:
    lines = [
        "# Repeatability analysis",
        "",
        (
            "This report measures variation between repeated runs of one environment. "
            "It does not apply the later central numerical acceptance policy, so "
            "`numeric_variation` is descriptive rather than a failure"
        ),
        "",
        "## Overview",
        "",
        f"- Runs analysed: **{analysis['run_count']}**",
        f"- Classification: **{analysis['overall_classification']}**",
        f"- Representative run: **{analysis.get('environment_representative_run') or 'none'}**",
        f"- Output observations: **{analysis['summary']['output_count']}**",
        "",
        "## Input runs",
        "",
        "| Run | Execution | Tasks | Observations | Started |",
        "|---|---|---:|---:|---|",
    ]
    for run in analysis.get("runs", []):
        lines.append(
            "| "
            + " | ".join(
                [
                    markdown_escape(run.get("run_id")),
                    markdown_escape(run.get("overall_execution_status")),
                    format_number(run.get("task_count")),
                    format_number(run.get("observation_count")),
                    markdown_escape(run.get("started_at_utc") or "—"),
                ]
            )
            + " |"
        )

    lines.extend(
        [
            "",
            "## Output classifications",
            "",
            "| Classification | Count | Meaning |",
            "|---|---:|---|",
        ]
    )
    meanings = {
        "exact": "Every repeat stored the same values or tensor bytes",
        "numeric_variation": "Structures match, but at least one numeric value differs",
        "exceptional_value_mismatch": "NaN, infinity or finite-value positions differ",
        "value_mismatch": "A non-numeric value differs",
        "structural_mismatch": "Payload structure, tensor shape or dtype differs",
        "missing_runs": "The output or one of its leaves is absent from one or more runs",
        "not_produced_consistently": "Runs disagree about whether the output was produced",
        "failed_to_produce": "Every run failed before producing this output",
        "skipped_unsupported": "Every run consistently reported this output as unsupported",
    }
    for status, count in analysis["summary"]["output_status_counts"].items():
        lines.append(f"| `{status}` | {count} | {meanings.get(status, '')} |")

    lines.extend(
        [
            "",
            "## Summary by category",
            "",
            "| Category | Exact | Numeric variation | Skipped | Inconsistent | Total |",
            "|---|---:|---:|---:|---:|---:|",
        ]
    )
    for category, counts in analysis["summary"]["category_status_counts"].items():
        exact = counts.get("exact", 0)
        variable = counts.get("numeric_variation", 0)
        skipped = counts.get("skipped_unsupported", 0)
        inconsistent = sum(
            count
            for status, count in counts.items()
            if status not in {"exact", "numeric_variation", "skipped_unsupported"}
        )
        lines.append(
            f"| {markdown_escape(category)} | {exact} | {variable} | {skipped} | {inconsistent} | "
            f"{sum(counts.values())} |"
        )

    variable_outputs = [
        output
        for output in analysis.get("outputs", [])
        if output.get("status") != "exact"
    ]
    variable_outputs.sort(
        key=lambda output: (
            0 if output.get("status") == "numeric_variation" else 1,
            float(output.get("maximum_relative_l2_error") or -1.0),
            float(output.get("maximum_absolute_error") or -1.0),
        ),
        reverse=True,
    )
    lines.extend(
        [
            "",
            "## Variable or inconsistent outputs",
            "",
            "| Level | Category | Test | Case | Profile | Output | Status | Max relative L2 | Max absolute | Representative |",
            "|---|---|---|---|---|---|---|---:|---:|---|",
        ]
    )
    for output in variable_outputs[:top_output_count]:
        identity = output.get("identity", {})
        lines.append(
            "| "
            + " | ".join(
                [
                    markdown_escape(output.get("level")),
                    markdown_escape(output.get("category")),
                    markdown_escape(identity.get("test_id")),
                    markdown_escape(identity.get("case_id")),
                    markdown_escape(identity.get("profile_id")),
                    markdown_escape(identity.get("output_id")),
                    f"`{markdown_escape(output.get('status'))}`",
                    format_number(output.get("maximum_relative_l2_error")),
                    format_number(output.get("maximum_absolute_error")),
                    markdown_escape(output.get("representative_run") or "—"),
                ]
            )
            + " |"
        )
    if not variable_outputs:
        lines.append("| — | — | — | — | — | — | All outputs exact | — | — | — |")
    elif len(variable_outputs) > top_output_count:
        lines.append("")
        lines.append(
            f"The table shows the first {top_output_count} of {len(variable_outputs)} non-exact outputs. "
            "The JSON contains all of them"
        )

    lines.extend(
        [
            "",
            "## Pairwise run overview",
            "",
            "| Run A | Run B | Structural mismatches | Exact-value mismatches | Max relative L2 | P95 relative L2 |",
            "|---|---|---:|---:|---:|---:|",
        ]
    )
    for pair in analysis.get("environment_pairwise_distances", []):
        lines.append(
            "| "
            + " | ".join(
                [
                    markdown_escape(pair.get("run_a")),
                    markdown_escape(pair.get("run_b")),
                    format_number(pair.get("structural_mismatch_count")),
                    format_number(pair.get("exact_value_mismatch_count")),
                    format_number(pair.get("maximum_relative_l2_error")),
                    format_number(pair.get("p95_relative_l2_error")),
                ]
            )
            + " |"
        )

    if plot_paths:
        lines.extend(["", "## Graphs", ""])
        for plot_path in plot_paths:
            lines.append(f"![{plot_path.stem}]({plot_path.name})")
            lines.append("")

    lines.extend(
        [
            "## Notes for the later GPU comparison",
            "",
            (
                "The JSON retains every run name, stable output identity, tensor hash, tensor artefact path, "
                "pairwise metric and representative-run choice. A later cross-environment tool should use "
                "the central numerical policy to assess both this repeatability envelope and the distance "
                "between the candidate and reference environments"
            ),
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def make_plots(analysis: Mapping[str, Any], output_directory: Path) -> list[Path]:
    try:
        import matplotlib.pyplot as plt
    except ImportError as exc:
        raise RuntimeError(
            "Matplotlib is required for repeatability graphs. Use --no-plots to skip them"
        ) from exc

    def finish_plot(figure: Any, title: str, caption: str) -> None:
        figure.suptitle(title, fontsize=12, fontweight="bold", y=0.985)
        figure.text(
            0.5,
            0.012,
            caption,
            ha="center",
            va="bottom",
            fontsize=8.5,
            wrap=True,
        )
        figure.tight_layout(rect=(0.0, 0.065, 1.0, 0.94))

    plot_paths: list[Path] = []

    categories = analysis["summary"]["category_status_counts"]
    if categories:
        names = list(categories)
        exact = [categories[name].get("exact", 0) for name in names]
        variable = [categories[name].get("numeric_variation", 0) for name in names]
        skipped = [categories[name].get("skipped_unsupported", 0) for name in names]
        inconsistent = [
            sum(
                count
                for status, count in categories[name].items()
                if status not in {"exact", "numeric_variation", "skipped_unsupported"}
            )
            for name in names
        ]
        positions = np.arange(len(names))
        figure, axis = plt.subplots(figsize=(max(9, len(names) * 0.65), 6))
        axis.bar(positions, exact, label="Exact")
        axis.bar(positions, variable, bottom=exact, label="Numeric variation")
        bottom = np.asarray(exact) + np.asarray(variable)
        axis.bar(positions, skipped, bottom=bottom, label="Skipped unsupported")
        bottom = bottom + np.asarray(skipped)
        axis.bar(positions, inconsistent, bottom=bottom, label="Inconsistent")
        axis.set_ylabel("Output count")
        axis.set_xticks(positions)
        axis.set_xticklabels(names, rotation=55, ha="right")
        axis.legend(title="Observed classification")
        axis.grid(True, axis="y", alpha=0.25)
        finish_plot(
            figure,
            "Repeatability classification by category",
            "Exact outputs match bit-for-bit. Numeric variation is structurally consistent but not "
            "identical. Inconsistent includes missing, failed or structurally different outputs.",
        )
        path = output_directory / "repeatability_status_by_category.png"
        figure.savefig(path, dpi=160)
        plt.close(figure)
        plot_paths.append(path)

    relative_values = [
        float(value)
        for output in analysis.get("outputs", [])
        for leaf in output.get("leaves", [])
        for pair in leaf.get("pairwise", [])
        if isinstance((value := pair.get("relative_l2_error")), (int, float))
        and math.isfinite(float(value))
        and float(value) > 0.0
    ]
    if relative_values:
        values = np.asarray(relative_values, dtype=np.float64)
        low = float(np.min(values))
        high = float(np.max(values))
        bin_count = min(40, max(10, len(relative_values) // 3))
        if high > low:
            bins = np.geomspace(low, high, bin_count + 1)
        else:
            bins = np.geomspace(low / 2.0, high * 2.0, 3)
        figure, axis = plt.subplots(figsize=(8, 5))
        axis.hist(values, bins=bins)
        axis.set_xscale("log")
        axis.set_xlabel("Relative L2 error (log scale)")
        axis.set_ylabel("Pairwise leaf comparisons")
        axis.grid(True, axis="y", alpha=0.25)
        finish_plot(
            figure,
            "Distribution of non-zero repeatability differences",
            "Only non-zero numerical differences are shown. Values further left are smaller and "
            "therefore more repeatable; exact matches are excluded from this histogram.",
        )
        path = output_directory / "repeatability_relative_l2_distribution.png"
        figure.savefig(path, dpi=160)
        plt.close(figure)
        plot_paths.append(path)

    ranked = [
        output
        for output in analysis.get("outputs", [])
        if isinstance(output.get("maximum_relative_l2_error"), (int, float))
        and float(output["maximum_relative_l2_error"]) > 0.0
    ]
    ranked.sort(key=lambda item: float(item["maximum_relative_l2_error"]), reverse=True)
    ranked = ranked[:20]
    if ranked:
        labels = [
            f"{item['identity']['test_id']}\n{item['identity']['case_id']} / {item['identity']['output_id']}"
            for item in reversed(ranked)
        ]
        values = [float(item["maximum_relative_l2_error"]) for item in reversed(ranked)]
        figure, axis = plt.subplots(figsize=(10, max(5, len(ranked) * 0.42)))
        positions = np.arange(len(ranked))
        axis.barh(positions, values)
        axis.set_xscale("log")
        axis.set_yticks(positions)
        axis.set_yticklabels(labels)
        axis.set_xlabel("Maximum relative L2 error (log scale)")
        axis.grid(True, axis="x", alpha=0.25)
        finish_plot(
            figure,
            "Outputs with the largest observed repeatability differences",
            "Ranked by the worst pairwise relative L2 error across repeat runs. Shorter bars and "
            "values further left indicate stronger repeatability.",
        )
        path = output_directory / "repeatability_top_variable_outputs.png"
        figure.savefig(path, dpi=160)
        plt.close(figure)
        plot_paths.append(path)

    return plot_paths


def write_json(path: Path, value: Any) -> None:
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def main() -> int:
    args = parse_args()
    input_directory = args.input_directory.resolve()
    output_directory = (
        args.output_directory.resolve()
        if args.output_directory
        else input_directory / "repeatability_analysis"
    )
    output_directory.mkdir(parents=True, exist_ok=True)

    run_directories = discover_run_directories(input_directory, args.pattern)
    runs = [load_run_bundle(path) for path in run_directories]
    analysis = build_analysis(
        runs,
        input_root=input_directory,
        verify_hash=not args.skip_artifact_hash_check,
    )

    plot_paths = [] if args.no_plots else make_plots(analysis, output_directory)
    analysis["plots"] = [path.name for path in plot_paths]

    json_path = output_directory / DEFAULT_JSON_NAME
    markdown_path = output_directory / DEFAULT_MARKDOWN_NAME
    write_json(json_path, analysis)
    write_markdown(
        analysis,
        markdown_path,
        plot_paths=plot_paths,
        top_output_count=max(1, args.top_output_count),
    )

    policy_path = None
    if args.write_populated_policy is not None:
        requested = Path(args.write_populated_policy)
        policy_path = requested if requested.is_absolute() else output_directory / requested
        template = load_policy_template(args.policy_template.resolve())
        populated = populate_policy_from_repeatability(
            template,
            analysis,
            source_name=json_path.name,
        )
        write_policy_json(policy_path, populated)

    print(f"Analysed {len(runs)} repeatability runs")
    print(f"Classification: {analysis['overall_classification']}")
    print(f"JSON: {json_path}")
    print(f"Markdown: {markdown_path}")
    for plot_path in plot_paths:
        print(f"Graph: {plot_path}")
    if policy_path is not None:
        print(f"Populated comparison policy: {policy_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
