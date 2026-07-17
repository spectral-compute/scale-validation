"""Populate and apply the central comparison policy.

This module is shared by the repeatability analyser and the two comparison
scripts. Keeping the calibration rules here means the same limits are used when
we compare analysis JSON and when we compare the underlying tensor artefacts.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, MutableMapping, Sequence


POLICY_FORMAT_VERSION = "comparison_policy_v1"
BUILTIN_TEMPLATE_PATH = Path(__file__).with_name("comparison_policy_template.json")
STATUS_ORDER = {"NA": 0, "PASS": 1, "MAYBE": 2, "FAIL": 3}

COMPARABLE_ANALYSIS_FIELDS = (
    "suite_name",
    "suite_version",
    "result_format_version",
    "test_catalogue_version",
    "root_seed",
    "dataset_manifest_sha256",
    "profile_ids",
)


def analysis_metadata(analysis: Mapping[str, Any]) -> dict[str, Any]:
    fields = analysis.get("compatibility", {}).get("fields", {})
    return {
        name: fields.get(name, {}).get("common_value")
        for name in COMPARABLE_ANALYSIS_FIELDS
    }


def compare_analysis_metadata(
    reference: Mapping[str, Any],
    candidate: Mapping[str, Any],
) -> dict[str, Any]:
    reference_values = analysis_metadata(reference)
    candidate_values = analysis_metadata(candidate)
    mismatches = [
        name
        for name in COMPARABLE_ANALYSIS_FIELDS
        if canonical_json(reference_values.get(name)) != canonical_json(candidate_values.get(name))
    ]
    return {
        "compatible": not mismatches,
        "mismatched_fields": mismatches,
        "reference": reference_values,
        "candidate": candidate_values,
    }


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def sha256_json(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RuntimeError(f"Required JSON file is missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"File is not valid JSON: {path}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def _fill_missing(target: MutableMapping[str, Any], defaults: Mapping[str, Any]) -> None:
    """Add absent values without replacing deliberate local edits."""

    for key, value in defaults.items():
        if key not in target or target[key] is None:
            target[key] = copy.deepcopy(value)
        elif isinstance(target[key], MutableMapping) and isinstance(value, Mapping):
            _fill_missing(target[key], value)


def load_policy_template(path: Path | None = None) -> dict[str, Any]:
    template_path = path or BUILTIN_TEMPLATE_PATH
    loaded = read_json(template_path)
    if not isinstance(loaded, dict):
        raise RuntimeError(f"Comparison policy must be a JSON object: {template_path}")

    # Add newly introduced built-in policies to older templates
    # Existing non-null values are always kept
    builtin = read_json(BUILTIN_TEMPLATE_PATH)
    _fill_missing(loaded, builtin)
    if loaded.get("comparison_policy_format_version") != POLICY_FORMAT_VERSION:
        raise RuntimeError(
            "Unsupported comparison policy format: "
            f"{loaded.get('comparison_policy_format_version')!r}"
        )
    return loaded


def _normalise_dtype(value: str | None) -> str:
    if not value:
        return "unknown"
    return value.lower().replace("torch.", "").replace("numpy.", "")


def _tensor_dtype(leaf: Mapping[str, Any]) -> str:
    representative = leaf.get("representative_run")
    runs = leaf.get("runs")
    if not isinstance(runs, Mapping):
        return "unknown"
    descriptor = runs.get(representative) if representative in runs else next(iter(runs.values()), None)
    if isinstance(descriptor, Mapping):
        return _normalise_dtype(str(descriptor.get("logical_dtype") or "unknown"))
    return "unknown"


def select_policy_id(leaf: Mapping[str, Any]) -> str:
    value_type = str(leaf.get("value_type"))
    if value_type not in {"tensor", "numeric_scalar"}:
        return "exact.value.v1"
    if value_type == "numeric_scalar":
        return "numeric.scalar.v1"

    dtype = _tensor_dtype(leaf)
    if dtype in {"bool", "uint8", "uint16", "uint32", "uint64", "int8", "int16", "int32", "int64"}:
        return "exact.value.v1"
    if dtype in {"float64", "complex128"}:
        return "numeric.float64.v1"
    if dtype in {"float32", "complex64"}:
        return "numeric.float32.v1"
    if dtype == "float16":
        return "numeric.float16.v1"
    if dtype == "bfloat16":
        return "numeric.bfloat16.v1"
    return "numeric.fallback.v1"


def _finite_number(value: Any, default: float = 0.0) -> float:
    if isinstance(value, (int, float)) and math.isfinite(float(value)):
        return float(value)
    return default


def _calibrated_limit(base: float, observed: float, multiplier: float, hard: float) -> tuple[float, bool]:
    requested = max(base, observed * multiplier)
    return min(requested, hard), requested > hard


def _policy_limits(
    policy: Mapping[str, Any],
    stage: str,
    observed: Mapping[str, Any],
    multiplier: float,
) -> tuple[dict[str, float], bool]:
    base = policy.get("base_limits", {}).get(stage, {})
    hard = policy.get("hard_limits", {})
    observed_values = {
        "atol": _finite_number(observed.get("maximum_absolute_error")),
        "rtol": _finite_number(observed.get("maximum_symmetric_relative_error")),
        "relative_l2": _finite_number(observed.get("maximum_relative_l2_error")),
        "maximum_bad_fraction": 0.0,
    }
    result: dict[str, float] = {}
    exceeded = False
    for name in ("atol", "rtol", "relative_l2", "maximum_bad_fraction"):
        value, clipped = _calibrated_limit(
            _finite_number(base.get(name)),
            observed_values[name],
            multiplier,
            _finite_number(hard.get(name), float("inf")),
        )
        result[name] = value
        exceeded = exceeded or clipped
    return result, exceeded


def _reference_leaf_envelope(leaf: Mapping[str, Any]) -> dict[str, Any]:
    summary = leaf.get("summary") if isinstance(leaf.get("summary"), Mapping) else {}
    maximum_symmetric = 0.0
    for pair in leaf.get("pairwise", []):
        maximum_symmetric = max(
            maximum_symmetric,
            _finite_number(pair.get("maximum_symmetric_relative_error")),
        )
    return {
        "status": leaf.get("status"),
        "maximum_absolute_error": summary.get("maximum_absolute_error"),
        "maximum_relative_l2_error": summary.get("maximum_relative_l2_error"),
        "maximum_symmetric_relative_error": maximum_symmetric,
        "maximum_mismatch_fraction": summary.get("maximum_mismatch_fraction"),
    }


def populate_policy_from_repeatability(
    template: Mapping[str, Any],
    analysis: Mapping[str, Any],
    *,
    source_name: str | None = None,
) -> dict[str, Any]:
    """Return a policy populated from one reference repeatability analysis.

    Existing values in ``output_policies`` are preserved. Missing fields and new
    output identities are added, which lets a manually tuned policy survive a
    later recalibration run
    """

    policy = copy.deepcopy(dict(template))
    _fill_missing(policy, read_json(BUILTIN_TEMPLATE_PATH))
    settings = policy["settings"]
    multiplier = float(settings["reference_variability_multiplier"])
    output_policies = policy.setdefault("output_policies", {})

    unstable_outputs: list[str] = []
    for output in analysis.get("outputs", []):
        identity_key = str(output.get("identity_key"))
        generated = {
            "identity": copy.deepcopy(output.get("identity")),
            "level": output.get("level"),
            "category": output.get("category"),
            "kind": output.get("kind"),
            "importance": output.get("importance"),
            "reference_status": output.get("status"),
            "leaves": {},
        }
        reference_output_unstable = str(output.get("status")) not in {"exact", "numeric_variation"}
        for leaf in output.get("leaves", []):
            leaf_path = str(leaf.get("path"))
            policy_id = select_policy_id(leaf)
            family = policy["policies"][policy_id]
            leaf_entry: dict[str, Any] = {
                "value_type": leaf.get("value_type"),
                "policy_id": policy_id,
                "reference_envelope": _reference_leaf_envelope(leaf),
            }
            if family.get("comparison_type") == "exact":
                leaf_entry["limits"] = {"repeatability": {}, "cross_environment": {}}
                leaf_entry["reference_qualified"] = leaf.get("status") == "exact"
            else:
                observed = leaf_entry["reference_envelope"]
                repeat_limits, repeat_clipped = _policy_limits(
                    family, "repeatability", observed, multiplier
                )
                cross_limits, cross_clipped = _policy_limits(
                    family, "cross_environment", observed, multiplier
                )
                leaf_entry["limits"] = {
                    "repeatability": repeat_limits,
                    "cross_environment": cross_limits,
                }
                leaf_entry["reference_qualified"] = (
                    leaf.get("status") in {"exact", "numeric_variation"}
                    and not repeat_clipped
                    and not cross_clipped
                )
                leaf_entry["hard_limit_was_reached"] = repeat_clipped or cross_clipped
            reference_output_unstable = reference_output_unstable or not leaf_entry["reference_qualified"]
            generated["leaves"][leaf_path] = leaf_entry

        generated["reference_qualified"] = not reference_output_unstable
        if reference_output_unstable:
            unstable_outputs.append(identity_key)
        existing = output_policies.get(identity_key)
        if isinstance(existing, Mapping) and existing.get("lock_calibration") is True:
            # Keep a deliberate output-specific policy exactly as supplied
            # Family-level hardcoded values are already preserved separately
            continue
        output_policies[identity_key] = generated

    policy["calibration"] = {
        **dict(policy.get("calibration", {})),
        "generated_at_utc": utc_now(),
        "source_name": source_name,
        "source_analysis_format_version": analysis.get("analysis_format_version"),
        "source_analysis_sha256": sha256_json(analysis),
        "reference_run_count": analysis.get("run_count"),
        "reference_overall_classification": analysis.get("overall_classification"),
        "output_policy_count": len(output_policies),
        "reference_unstable_output_count": len(unstable_outputs),
        "reference_unstable_output_keys": sorted(unstable_outputs),
    }
    semantic_policy = {
        key: value
        for key, value in policy.items()
        if key not in {"policy_sha256", "calibration"}
    }
    policy["policy_sha256"] = sha256_json(semantic_policy)
    return policy


def resolve_leaf_policy(
    policy: Mapping[str, Any],
    identity_key: str,
    leaf_path: str,
) -> tuple[Mapping[str, Any], Mapping[str, Any]]:
    output = policy.get("output_policies", {}).get(identity_key)
    if not isinstance(output, Mapping):
        raise KeyError(f"No output policy for {identity_key}")
    leaf = output.get("leaves", {}).get(leaf_path)
    if not isinstance(leaf, Mapping):
        raise KeyError(f"No leaf policy for {identity_key} {leaf_path}")
    family = policy.get("policies", {}).get(leaf.get("policy_id"))
    if not isinstance(family, Mapping):
        raise KeyError(f"Unknown policy family {leaf.get('policy_id')!r}")
    return leaf, family


def combine_statuses(statuses: Sequence[str]) -> str:
    if not statuses:
        return "NA"
    return max(statuses, key=lambda value: STATUS_ORDER.get(value, 99))


def numeric_limit_ratios(metrics: Mapping[str, Any], limits: Mapping[str, Any]) -> dict[str, float]:
    # Raw comparisons provide a scaled allclose-style error and a bad-element fraction
    # Repeatability JSON only has aggregate absolute and symmetric-relative envelopes
    if isinstance(metrics.get("maximum_scaled_error"), (int, float)):
        mapping = {
            "maximum_scaled_error": None,
            "relative_l2_error": "relative_l2",
            "bad_fraction": "maximum_bad_fraction",
        }
    else:
        mapping = {
            "maximum_absolute_error": "atol",
            "maximum_symmetric_relative_error": "rtol",
            "relative_l2_error": "relative_l2",
            "bad_fraction": "maximum_bad_fraction",
        }
    ratios: dict[str, float] = {}
    for metric_name, limit_name in mapping.items():
        metric = _finite_number(metrics.get(metric_name))
        limit = 1.0 if limit_name is None else _finite_number(limits.get(limit_name))
        if limit == 0.0:
            ratios[metric_name] = 0.0 if metric == 0.0 else 1e300
        else:
            ratios[metric_name] = metric / limit
    return ratios


def judge_numeric_metrics(
    metrics: Mapping[str, Any],
    limits: Mapping[str, Any],
    *,
    maybe_multiplier: float,
    require_exceptional_masks_match: bool = True,
) -> tuple[str, dict[str, float], str]:
    if not metrics.get("comparable", True):
        return "FAIL", {}, str(metrics.get("reason") or "not comparable")
    if require_exceptional_masks_match and any(
        int(metrics.get(name, 0)) > 0
        for name in (
            "nan_mask_mismatch_count",
            "infinity_mask_mismatch_count",
            "finite_mask_mismatch_count",
        )
    ):
        return "FAIL", {}, "NaN, infinity or finite-value masks differ"

    ratios = numeric_limit_ratios(metrics, limits)
    worst = max(ratios.values(), default=0.0)
    if worst <= 1.0:
        return "PASS", ratios, "within the populated numerical limits"
    if worst <= maybe_multiplier:
        return "MAYBE", ratios, "outside the pass limit but still within the review band"
    return "FAIL", ratios, "outside the populated numerical limits"


def judge_repeatability_leaf(
    leaf: Mapping[str, Any],
    leaf_policy: Mapping[str, Any],
    family: Mapping[str, Any],
    *,
    maybe_multiplier: float,
) -> tuple[str, str, dict[str, float]]:
    status = str(leaf.get("status"))
    if family.get("comparison_type") == "exact":
        if status == "exact":
            return "PASS", "all repeat runs match exactly", {}
        return "FAIL", f"exact policy but repeatability status is {status}", {}
    if status not in {"exact", "numeric_variation"}:
        return "FAIL", f"repeatability status is {status}", {}

    envelope = _reference_leaf_envelope(leaf)
    metrics = {
        "comparable": True,
        "maximum_absolute_error": envelope.get("maximum_absolute_error"),
        "maximum_symmetric_relative_error": envelope.get("maximum_symmetric_relative_error"),
        "relative_l2_error": envelope.get("maximum_relative_l2_error"),
        "bad_fraction": 0.0,
        "nan_mask_mismatch_count": 0,
        "infinity_mask_mismatch_count": 0,
        "finite_mask_mismatch_count": 0,
    }
    return_value, ratios, reason = judge_numeric_metrics(
        metrics,
        leaf_policy.get("limits", {}).get("repeatability", {}),
        maybe_multiplier=maybe_multiplier,
        require_exceptional_masks_match=bool(
            family.get("require_exceptional_value_masks_match", True)
        ),
    )
    return return_value, reason, ratios
