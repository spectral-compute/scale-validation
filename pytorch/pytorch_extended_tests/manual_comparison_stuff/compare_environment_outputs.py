#!/usr/bin/env python3
"""Compare raw result bundles from several environments against ``reference``.

Expected layout::

    comparison_root/
    ├── comparison_policy_template.json
    ├── reference/
    │   ├── run_001/
    │   └── run_002/
    ├── a100_gcc/
    │   ├── any_run_name/
    │   └── another_run/
    └── h100_clang/
        └── run_001/

Each run directory must be an unmodified copy of what the suite wrote to
``/tmp/ci_benchmarks/pytorch``. The script first builds an intra-environment
repeatability analysis for every environment. It then populates the central
policy from the reference runs and compares every candidate run against every
reference run using the raw scalar and tensor values.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np

SCRIPT_DIRECTORY = Path(__file__).resolve().parent
if str(SCRIPT_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIRECTORY))

from analyse_repeatability import (  # noqa: E402
    NUMERIC_RECORD_OUTPUT_IDS,
    RunBundle,
    build_analysis,
    canonical_json,
    flatten_payload,
    load_run_bundle,
    load_tensor,
)
from comparison_graphs import make_detailed_model_plots  # noqa: E402
from comparison_policy import (  # noqa: E402
    BUILTIN_TEMPLATE_PATH,
    combine_statuses,
    compare_analysis_metadata,
    judge_numeric_metrics,
    judge_repeatability_leaf,
    load_policy_template,
    populate_policy_from_repeatability,
    resolve_leaf_policy,
    sha256_json,
    write_json,
)


COMPARISON_FORMAT_VERSION = "environment_output_comparison_v1"
OUTPUT_DIRECTORY_NAME = "comparison_results"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_directory", nargs="?", type=Path, default=Path.cwd())
    parser.add_argument("--reference-folder", default="reference")
    parser.add_argument("--policy-template", type=Path)
    parser.add_argument("--policy-output", type=Path)
    parser.add_argument("--output-directory", type=Path)
    parser.add_argument("--skip-artifact-hash-check", action="store_true")
    parser.add_argument(
        "--retain-all-pairs",
        action="store_true",
        help="Retain every reference/candidate pair in JSON instead of only summaries",
    )
    parser.add_argument("--no-plots", action="store_true")
    return parser.parse_args()


def _is_bundle(path: Path) -> bool:
    return all(
        (path / name).is_file()
        for name in ("run_manifest.json", "observations.jsonl", "test_status.json")
    )


def discover_environment_runs(path: Path) -> list[Path]:
    if _is_bundle(path):
        return [path]
    runs = [child for child in sorted(path.iterdir()) if child.is_dir() and _is_bundle(child)]
    if not runs:
        raise RuntimeError(f"No raw result bundles found beneath environment folder {path}")
    return runs


def discover_environments(
    input_directory: Path,
    reference_folder: str,
    output_directory: Path,
) -> tuple[Path, list[Path]]:
    reference = input_directory / reference_folder
    if not reference.is_dir():
        raise RuntimeError(f"Reference environment folder is missing: {reference}")
    candidates = []
    for path in sorted(input_directory.iterdir()):
        if not path.is_dir() or path == reference or path == output_directory:
            continue
        try:
            discover_environment_runs(path)
        except RuntimeError:
            continue
        candidates.append(path)
    if not candidates:
        raise RuntimeError(f"No candidate environment folders found beneath {input_directory}")
    return reference, candidates


def output_map(analysis: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    return {
        str(output.get("identity_key")): output
        for output in analysis.get("outputs", [])
        if isinstance(output, Mapping)
    }


def leaf_map(output: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    return {
        str(leaf.get("path")): leaf
        for leaf in output.get("leaves", [])
        if isinstance(leaf, Mapping)
    }


def records_by_key(runs: Sequence[RunBundle]) -> dict[str, dict[str, Mapping[str, Any]]]:
    result: dict[str, dict[str, Mapping[str, Any]]] = defaultdict(dict)
    for run in runs:
        for key, record in run.observations.items():
            result[key][run.run_id] = record
    return dict(result)


def flattened_produced_record(record: Mapping[str, Any]) -> dict[str, Any]:
    if record.get("status") != "produced":
        return {}
    numeric_scalars = (
        record.get("kind") in {"scalar", "series"}
        or record.get("output_id") in NUMERIC_RECORD_OUTPUT_IDS
    )
    return {
        leaf.path: leaf
        for leaf in flatten_payload(record.get("payload"), numeric_scalars=numeric_scalars)
    }


def _metadata_matches(left: Mapping[str, Any], right: Mapping[str, Any]) -> bool:
    return all(left.get(name) == right.get(name) for name in ("logical_dtype", "shape", "numel"))


def numeric_array_metrics(
    left: np.ndarray,
    right: np.ndarray,
    limits: Mapping[str, Any],
) -> dict[str, Any]:
    if left.shape != right.shape:
        return {
            "comparable": False,
            "reason": "shape_mismatch",
            "left_shape": list(left.shape),
            "right_shape": list(right.shape),
        }
    left_values = np.asarray(left)
    right_values = np.asarray(right)
    left_inexact = np.issubdtype(left_values.dtype, np.inexact)
    right_inexact = np.issubdtype(right_values.dtype, np.inexact)
    left_nan = np.isnan(left_values) if left_inexact else np.zeros(left.shape, dtype=bool)
    right_nan = np.isnan(right_values) if right_inexact else np.zeros(right.shape, dtype=bool)
    left_inf = np.isinf(left_values) if left_inexact else np.zeros(left.shape, dtype=bool)
    right_inf = np.isinf(right_values) if right_inexact else np.zeros(right.shape, dtype=bool)
    left_finite = ~(left_nan | left_inf)
    right_finite = ~(right_nan | right_inf)
    jointly_finite = left_finite & right_finite

    metrics: dict[str, Any] = {
        "comparable": True,
        "element_count": int(left_values.size),
        "nan_mask_mismatch_count": int(np.count_nonzero(left_nan != right_nan)),
        "infinity_mask_mismatch_count": int(np.count_nonzero(left_inf != right_inf)),
        "finite_mask_mismatch_count": int(np.count_nonzero(left_finite != right_finite)),
        "jointly_finite_count": int(np.count_nonzero(jointly_finite)),
    }
    if not np.any(jointly_finite):
        metrics.update(
            {
                "exact_equal": bool(np.array_equal(left_values, right_values, equal_nan=True)),
                "maximum_absolute_error": 0.0,
                "maximum_symmetric_relative_error": 0.0,
                "relative_l2_error": 0.0,
                "maximum_scaled_error": 0.0,
                "bad_count": 0,
                "bad_fraction": 0.0,
            }
        )
        return metrics

    conversion = np.complex128 if np.iscomplexobj(left_values) or np.iscomplexobj(right_values) else np.float64
    left_f = left_values[jointly_finite].astype(conversion)
    right_f = right_values[jointly_finite].astype(conversion)
    difference = np.abs(left_f - right_f).astype(np.float64)
    left_abs = np.abs(left_f).astype(np.float64)
    right_abs = np.abs(right_f).astype(np.float64)
    scale = np.maximum(left_abs, right_abs)
    atol = float(limits.get("atol", 0.0))
    rtol = float(limits.get("rtol", 0.0))
    allowed = atol + rtol * scale
    bad = difference > allowed
    denominator = np.maximum(scale, np.finfo(np.float64).tiny)
    relative = difference / denominator
    relative_l2 = float(np.linalg.norm(difference.ravel(), 2)) / max(
        float(np.linalg.norm(left_abs.ravel(), 2)),
        float(np.linalg.norm(right_abs.ravel(), 2)),
        np.finfo(np.float64).tiny,
    )
    scaled = difference / np.maximum(allowed, np.finfo(np.float64).tiny)
    metrics.update(
        {
            "exact_equal": bool(np.array_equal(left_values, right_values, equal_nan=True)),
            "maximum_absolute_error": float(np.max(difference)),
            "maximum_symmetric_relative_error": float(np.max(relative)),
            "relative_l2_error": relative_l2,
            "maximum_scaled_error": float(np.max(scaled)),
            "bad_count": int(np.count_nonzero(bad)),
            "bad_fraction": float(np.count_nonzero(bad) / difference.size),
        }
    )
    return metrics


def exact_pair(left: Any, right: Any) -> dict[str, Any]:
    matches = canonical_json(left) == canonical_json(right)
    return {"status": "PASS" if matches else "FAIL", "exact_equal": matches}


def compare_leaf_pair(
    reference_run: RunBundle,
    reference_leaf: Any,
    candidate_run: RunBundle,
    candidate_leaf: Any,
    leaf_policy: Mapping[str, Any],
    family: Mapping[str, Any],
    *,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
    tensor_cache: dict[tuple[str, str], np.ndarray],
    maybe_multiplier: float,
) -> dict[str, Any]:
    if reference_leaf.value_type != candidate_leaf.value_type:
        return {"status": "FAIL", "reason": "leaf value types differ"}
    if family.get("comparison_type") == "exact":
        if reference_leaf.value_type == "tensor":
            left = reference_leaf.value
            right = candidate_leaf.value
            matches = _metadata_matches(left, right) and left.get("sha256") == right.get("sha256")
            return {
                "status": "PASS" if matches else "FAIL",
                "reason": "exact tensor match" if matches else "exact tensor differs",
            }
        result = exact_pair(reference_leaf.value, candidate_leaf.value)
        result["reason"] = "exact values match" if result["status"] == "PASS" else "exact values differ"
        return result

    limits = leaf_policy.get("limits", {}).get("cross_environment", {})
    if reference_leaf.value_type == "tensor":
        if not _metadata_matches(reference_leaf.value, candidate_leaf.value):
            return {"status": "FAIL", "reason": "tensor dtype, shape or element count differs"}
        if reference_leaf.value.get("sha256") == candidate_leaf.value.get("sha256"):
            metrics = {
                "comparable": True,
                "exact_equal": True,
                "maximum_absolute_error": 0.0,
                "maximum_symmetric_relative_error": 0.0,
                "relative_l2_error": 0.0,
                "maximum_scaled_error": 0.0,
                "bad_count": 0,
                "bad_fraction": 0.0,
                "nan_mask_mismatch_count": 0,
                "infinity_mask_mismatch_count": 0,
                "finite_mask_mismatch_count": 0,
            }
            status, ratios, reason = judge_numeric_metrics(
                metrics,
                limits,
                maybe_multiplier=maybe_multiplier,
                require_exceptional_masks_match=bool(
                    family.get("require_exceptional_value_masks_match", True)
                ),
            )
            return {"status": status, "reason": reason, "metrics": metrics, "limit_ratios": ratios}
        left_key = (reference_run.path.as_posix(), str(reference_leaf.value.get("relative_path")))
        right_key = (candidate_run.path.as_posix(), str(candidate_leaf.value.get("relative_path")))
        if left_key not in tensor_cache:
            tensor_cache[left_key] = load_tensor(
                reference_run,
                reference_leaf.value,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
            )
        if right_key not in tensor_cache:
            tensor_cache[right_key] = load_tensor(
                candidate_run,
                candidate_leaf.value,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
            )
        left = tensor_cache[left_key]
        right = tensor_cache[right_key]
        metrics = numeric_array_metrics(left, right, limits)
    elif reference_leaf.value_type == "numeric_scalar":
        metrics = numeric_array_metrics(
            np.asarray([reference_leaf.value], dtype=np.float64),
            np.asarray([candidate_leaf.value], dtype=np.float64),
            limits,
        )
    else:
        return {"status": "FAIL", "reason": "numeric policy was assigned to a non-numeric leaf"}

    status, ratios, reason = judge_numeric_metrics(
        metrics,
        limits,
        maybe_multiplier=maybe_multiplier,
        require_exceptional_masks_match=bool(
            family.get("require_exceptional_value_masks_match", True)
        ),
    )
    return {"status": status, "reason": reason, "metrics": metrics, "limit_ratios": ratios}


def assess_repeatability_output(
    output: Mapping[str, Any] | None,
    identity_key: str,
    policy: Mapping[str, Any],
) -> dict[str, Any]:
    if output is None:
        return {"status": "FAIL", "reason": "repeatability output is missing"}
    output_policy = policy.get("output_policies", {}).get(identity_key)
    if not isinstance(output_policy, Mapping):
        return {"status": "NA", "reason": "no populated output policy"}
    settings = policy.get("settings", {})
    maybe_multiplier = float(settings.get("maybe_limit_multiplier", 1.5))
    leaves = leaf_map(output)
    leaf_results = []
    for path, configured in sorted(output_policy.get("leaves", {}).items()):
        leaf = leaves.get(path)
        if leaf is None:
            leaf_results.append({"path": path, "status": "FAIL", "reason": "leaf is missing"})
            continue
        leaf_policy, family = resolve_leaf_policy(policy, identity_key, path)
        status, reason, ratios = judge_repeatability_leaf(
            leaf,
            leaf_policy,
            family,
            maybe_multiplier=maybe_multiplier,
        )
        leaf_results.append({"path": path, "status": status, "reason": reason, "limit_ratios": ratios})
    return {
        "status": combine_statuses([str(item["status"]) for item in leaf_results]),
        "leaf_results": leaf_results,
    }


def compare_output_raw(
    identity_key: str,
    reference_runs: Sequence[RunBundle],
    candidate_runs: Sequence[RunBundle],
    reference_analysis_output: Mapping[str, Any] | None,
    candidate_analysis_output: Mapping[str, Any] | None,
    reference_records: Mapping[str, Mapping[str, Any]],
    candidate_records: Mapping[str, Mapping[str, Any]],
    policy: Mapping[str, Any],
    *,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
    tensor_cache: dict[tuple[str, str], np.ndarray],
    retain_all_pairs: bool,
) -> dict[str, Any]:
    output_policy = policy.get("output_policies", {}).get(identity_key)
    identity = (
        reference_analysis_output.get("identity")
        if isinstance(reference_analysis_output, Mapping)
        else candidate_analysis_output.get("identity")
        if isinstance(candidate_analysis_output, Mapping)
        else None
    )
    base = {
        "identity_key": identity_key,
        "identity": identity,
        "level": reference_analysis_output.get("level") if reference_analysis_output else None,
        "category": reference_analysis_output.get("category") if reference_analysis_output else None,
        "importance": reference_analysis_output.get("importance") if reference_analysis_output else None,
    }
    if not isinstance(output_policy, Mapping):
        return {**base, "status": "NA", "reason": "no populated output policy"}
    if (
        reference_analysis_output is not None
        and candidate_analysis_output is not None
        and reference_analysis_output.get("kind") != candidate_analysis_output.get("kind")
    ):
        return {**base, "status": "FAIL", "reason": "output kinds differ"}

    reference_repeatability = assess_repeatability_output(reference_analysis_output, identity_key, policy)
    candidate_repeatability = assess_repeatability_output(candidate_analysis_output, identity_key, policy)
    if reference_repeatability["status"] == "FAIL":
        return {
            **base,
            "status": "NA",
            "reason": "reference repeatability did not qualify",
            "reference_repeatability": reference_repeatability,
            "candidate_repeatability": candidate_repeatability,
        }
    reference_paths = set(leaf_map(reference_analysis_output or {}))
    candidate_paths = set(leaf_map(candidate_analysis_output or {}))
    if reference_paths != candidate_paths:
        return {
            **base,
            "status": "FAIL",
            "reason": "reference and candidate output structures contain different leaf paths",
            "missing_candidate_leaf_paths": sorted(reference_paths - candidate_paths),
            "extra_candidate_leaf_paths": sorted(candidate_paths - reference_paths),
            "reference_repeatability": reference_repeatability,
            "candidate_repeatability": candidate_repeatability,
        }

    settings = policy.get("settings", {})
    maybe_multiplier = float(settings.get("maybe_limit_multiplier", 1.5))
    flattened_reference = {
        run.run_id: flattened_produced_record(reference_records.get(run.run_id, {}))
        for run in reference_runs
    }
    flattened_candidate = {
        run.run_id: flattened_produced_record(candidate_records.get(run.run_id, {}))
        for run in candidate_runs
    }
    pair_results: list[dict[str, Any]] = []
    leaf_summaries: list[dict[str, Any]] = []

    for path in sorted(output_policy.get("leaves", {})):
        leaf_policy, family = resolve_leaf_policy(policy, identity_key, path)
        leaf_pairs: list[dict[str, Any]] = []
        for reference_run in reference_runs:
            reference_leaf = flattened_reference.get(reference_run.run_id, {}).get(path)
            for candidate_run in candidate_runs:
                candidate_leaf = flattened_candidate.get(candidate_run.run_id, {}).get(path)
                if reference_leaf is None or candidate_leaf is None:
                    result = {"status": "FAIL", "reason": "leaf is missing from a raw run"}
                else:
                    result = compare_leaf_pair(
                        reference_run,
                        reference_leaf,
                        candidate_run,
                        candidate_leaf,
                        leaf_policy,
                        family,
                        verify_hash=verify_hash,
                        verified_paths=verified_paths,
                        tensor_cache=tensor_cache,
                        maybe_multiplier=maybe_multiplier,
                    )
                pair = {
                    "path": path,
                    "reference_run": reference_run.run_id,
                    "candidate_run": candidate_run.run_id,
                    **result,
                }
                pair_results.append(pair)
                leaf_pairs.append(pair)
        def pair_rank(item: Mapping[str, Any]) -> tuple[int, float]:
            status_rank = {"NA": 0, "PASS": 1, "MAYBE": 2, "FAIL": 3}.get(str(item.get("status")), 4)
            ratio = max(item.get("limit_ratios", {}).values(), default=0.0)
            return status_rank, float(ratio)

        worst_pair = max(leaf_pairs, key=pair_rank) if leaf_pairs else None
        leaf_summaries.append(
            {
                "path": path,
                "policy_id": leaf_policy.get("policy_id"),
                "status": combine_statuses([str(item["status"]) for item in leaf_pairs]),
                "pair_count": len(leaf_pairs),
                "status_counts": dict(sorted(Counter(str(item["status"]) for item in leaf_pairs).items())),
                "worst_limit_ratio": max(
                    (
                        max(item.get("limit_ratios", {}).values(), default=0.0)
                        for item in leaf_pairs
                    ),
                    default=0.0,
                ),
                "worst_pair": worst_pair,
            }
        )

    cross_status = combine_statuses([str(item["status"]) for item in leaf_summaries])
    status = combine_statuses(
        [cross_status, str(candidate_repeatability["status"])]
    )
    if len(reference_runs) < int(settings.get("minimum_reference_runs", 3)):
        status = combine_statuses([status, "MAYBE"])
    if len(candidate_runs) < int(settings.get("minimum_candidate_runs", 3)):
        status = combine_statuses([status, "MAYBE"])
    return {
        **base,
        "status": status,
        "reference_repeatability": reference_repeatability,
        "candidate_repeatability": candidate_repeatability,
        "cross_environment_status": cross_status,
        "leaf_summaries": leaf_summaries,
        "pairwise": pair_results if retain_all_pairs else None,
    }


def compare_environment(
    name: str,
    reference_runs: Sequence[RunBundle],
    candidate_runs: Sequence[RunBundle],
    reference_analysis: Mapping[str, Any],
    candidate_analysis: Mapping[str, Any],
    policy: Mapping[str, Any],
    *,
    verify_hash: bool,
    retain_all_pairs: bool,
) -> dict[str, Any]:
    metadata = compare_analysis_metadata(reference_analysis, candidate_analysis)
    reference_analysis_outputs = output_map(reference_analysis)
    candidate_analysis_outputs = output_map(candidate_analysis)
    reference_records_all = records_by_key(reference_runs)
    candidate_records_all = records_by_key(candidate_runs)
    keys = sorted(
        set(policy.get("output_policies", {}))
        | set(reference_analysis_outputs)
        | set(candidate_analysis_outputs)
    )
    verified_paths: set[tuple[str, str]] = set()
    tensor_cache: dict[tuple[str, str], np.ndarray] = {}
    outputs = []
    for key in keys:
        outputs.append(
            compare_output_raw(
                key,
                reference_runs,
                candidate_runs,
                reference_analysis_outputs.get(key),
                candidate_analysis_outputs.get(key),
                reference_records_all.get(key, {}),
                candidate_records_all.get(key, {}),
                policy,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
                tensor_cache=tensor_cache,
                retain_all_pairs=retain_all_pairs,
            )
        )
    required = [item for item in outputs if item.get("importance") == "required"]
    overall = combine_statuses([str(item.get("status")) for item in required or outputs])
    if not metadata["compatible"]:
        overall = "FAIL"
    counts = Counter(str(item.get("status")) for item in outputs)
    level_counts: dict[str, Counter[str]] = defaultdict(Counter)
    for output in outputs:
        level_counts[str(output.get("level"))][str(output.get("status"))] += 1
    return {
        "environment": name,
        "overall_status": overall,
        "metadata_compatibility": metadata,
        "reference_run_count": len(reference_runs),
        "candidate_run_count": len(candidate_runs),
        "status_counts": dict(sorted(counts.items())),
        "level_status_counts": {
            level: dict(sorted(values.items())) for level, values in sorted(level_counts.items())
        },
        "verified_tensor_artifact_count": len(verified_paths) if verify_hash else None,
        "outputs": outputs,
    }


def write_markdown(
    result: Mapping[str, Any],
    path: Path,
    plots: Sequence[Path],
    plot_details: Sequence[Mapping[str, Any]],
) -> None:
    environments = [str(item["environment"]) for item in result.get("environments", [])]
    lines = []
    lines.append("| Compared item | " + " | ".join(environments) + " |")
    lines.append("|---|" + "---|" * len(environments))
    lines.append(
        "| **Overall** | "
        + " | ".join(f"**{item['overall_status']}**" for item in result.get("environments", []))
        + " |"
    )
    lines.append(
        "| Runs | "
        + " | ".join(str(item["candidate_run_count"]) for item in result.get("environments", []))
        + " |"
    )
    lines.extend(["", "# Environment output comparison details"])

    levels = sorted(
        {
            str(output.get("level"))
            for environment in result.get("environments", [])
            for output in environment.get("outputs", [])
        }
    )
    for level in levels:
        lines.extend(["", f"## {level}", ""])
        lines.append("| Thing compared | " + " | ".join(environments) + " |")
        lines.append("|---|" + "---|" * len(environments))
        identities: dict[str, Mapping[str, Any]] = {}
        statuses: dict[tuple[str, str], str] = {}
        for environment in result.get("environments", []):
            for output in environment.get("outputs", []):
                if str(output.get("level")) != level:
                    continue
                key = str(output.get("identity_key"))
                identities[key] = output.get("identity") or {}
                statuses[(str(environment["environment"]), key)] = str(output.get("status"))
        for key in sorted(identities):
            identity = identities[key]
            label = " / ".join(
                str(identity.get(name))
                for name in ("test_id", "case_id", "profile_id", "output_id")
            )
            lines.append(
                "| " + label + " | "
                + " | ".join(statuses.get((environment, key), "NA") for environment in environments)
                + " |"
            )

    lines.extend(
        [
            "",
            "## Status meanings",
            "",
            "- **PASS:** repeatability and all reference-to-candidate raw comparisons are within policy",
            "- **MAYBE:** a result is borderline or there are fewer repeats than the policy recommends",
            "- **FAIL:** a required exact match, structure check or numerical limit failed",
            "- **NA:** there is no valid comparison, commonly because the reference output did not qualify",
        ]
    )
    if plots:
        lines.extend(["", "## Graphs", ""])
        details_by_path = {str(item.get("path")): item for item in plot_details}
        for plot in plots:
            detail = details_by_path.get(plot.name, {})
            title = str(detail.get("title") or plot.stem)
            lines.append(f"### {title}")
            lines.append("")
            lines.append(f"![{title}]({plot.name})")
            caption = detail.get("caption")
            if caption:
                lines.append("")
                lines.append(f"*{caption}*")
            lines.append("")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def make_plots(result: Mapping[str, Any], output_directory: Path) -> list[Path]:
    try:
        import matplotlib.pyplot as plt
    except ImportError as exc:
        raise RuntimeError("Matplotlib is required unless --no-plots is used") from exc

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

    environments = result.get("environments", [])
    if not environments:
        return []
    names = [str(item["environment"]) for item in environments]
    positions = np.arange(len(names))
    bottom = np.zeros(len(names), dtype=np.int64)
    figure, axis = plt.subplots(figsize=(max(8, len(names) * 1.3), 5.5))
    for status in ("PASS", "MAYBE", "FAIL", "NA"):
        values = np.asarray([item.get("status_counts", {}).get(status, 0) for item in environments])
        axis.bar(positions, values, bottom=bottom, label=status)
        bottom += values
    axis.set_xticks(positions)
    axis.set_xticklabels(names, rotation=35, ha="right")
    axis.set_ylabel("Compared output count")
    axis.legend(title="Comparison status")
    axis.grid(True, axis="y", alpha=0.25)
    finish_plot(
        figure,
        "Cross-environment comparison results",
        "PASS is within policy, FAIL exceeds policy or has a structural problem, MAYBE needs raw "
        "inspection, and NA could not be compared. Counts include repeatability and cross-environment checks.",
    )
    status_path = output_directory / "environment_status_counts.png"
    figure.savefig(status_path, dpi=160)
    plt.close(figure)

    worst = []
    for environment in environments:
        ratios = [
            float(leaf.get("worst_limit_ratio", 0.0))
            for output in environment.get("outputs", [])
            for leaf in output.get("leaf_summaries", [])
            if math.isfinite(float(leaf.get("worst_limit_ratio", 0.0)))
        ]
        worst.append(max(ratios, default=0.0))
    positive_logs = [math.log10(value) for value in worst if value > 0.0]
    zero_floor = min(-1.0, min(positive_logs, default=0.0) - 1.0)
    display_values = [math.log10(value) if value > 0.0 else zero_floor for value in worst]
    figure, axis = plt.subplots(figsize=(max(8, len(names) * 1.3), 5))
    bars = axis.bar(positions, display_values)
    axis.bar_label(bars, labels=[f"{value:.3g}" for value in worst], padding=3, fontsize=8)
    axis.axhline(0.0, linestyle="--", linewidth=1.2, label="Pass limit (ratio = 1)")
    axis.set_xticks(positions)
    axis.set_xticklabels(names, rotation=35, ha="right")
    axis.set_ylabel("log10(worst observed metric ÷ pass limit)")
    axis.set_ylim(
        min(zero_floor - 0.5, min(display_values, default=zero_floor) - 0.5),
        max(1.0, max(display_values, default=0.0) * 1.05),
    )
    axis.legend()
    axis.grid(True, axis="y", alpha=0.25)
    finish_plot(
        figure,
        "Worst numerical tolerance ratio by environment",
        "The dashed zero line is the pass boundary: negative log10 ratios pass and positive ratios "
        "exceed a limit. Bar labels show the original ratio; exact zeros are placed at the chart floor.",
    )
    ratio_path = output_directory / "environment_worst_tolerance_ratio.png"
    figure.savefig(ratio_path, dpi=160)
    plt.close(figure)
    return [status_path, ratio_path]


def main() -> int:
    args = parse_args()
    input_directory = args.input_directory.resolve()
    output_directory = (
        args.output_directory.resolve()
        if args.output_directory
        else input_directory / OUTPUT_DIRECTORY_NAME
    )
    output_directory.mkdir(parents=True, exist_ok=True)
    reference_folder, candidate_folders = discover_environments(
        input_directory,
        args.reference_folder,
        output_directory,
    )

    reference_run_paths = discover_environment_runs(reference_folder)
    reference_runs = [load_run_bundle(path) for path in reference_run_paths]
    runs_by_environment: dict[str, Sequence[RunBundle]] = {
        reference_folder.name: reference_runs
    }
    reference_analysis = build_analysis(
        reference_runs,
        input_root=reference_folder,
        verify_hash=not args.skip_artifact_hash_check,
    )

    if args.policy_template:
        template_path = args.policy_template.resolve()
    elif (input_directory / "comparison_policy.json").is_file():
        template_path = input_directory / "comparison_policy.json"
    elif (input_directory / "comparison_policy_template.json").is_file():
        template_path = input_directory / "comparison_policy_template.json"
    else:
        template_path = BUILTIN_TEMPLATE_PATH
    template = load_policy_template(template_path)
    policy = populate_policy_from_repeatability(
        template,
        reference_analysis,
        source_name=reference_folder.name,
    )
    policy_output = (
        args.policy_output.resolve()
        if args.policy_output
        else input_directory / "comparison_policy.json"
    )
    write_json(policy_output, policy)

    environment_results = []
    analyses = {reference_folder.name: reference_analysis}
    for folder in candidate_folders:
        candidate_runs = [load_run_bundle(path) for path in discover_environment_runs(folder)]
        runs_by_environment[folder.name] = candidate_runs
        candidate_analysis = build_analysis(
            candidate_runs,
            input_root=folder,
            verify_hash=not args.skip_artifact_hash_check,
        )
        analyses[folder.name] = candidate_analysis
        environment_results.append(
            compare_environment(
                folder.name,
                reference_runs,
                candidate_runs,
                reference_analysis,
                candidate_analysis,
                policy,
                verify_hash=not args.skip_artifact_hash_check,
                retain_all_pairs=args.retain_all_pairs,
            )
        )

    result = {
        "comparison_format_version": COMPARISON_FORMAT_VERSION,
        "comparison_kind": "raw_cross_environment_output_comparison",
        "input_directory": input_directory.as_posix(),
        "reference_environment": reference_folder.name,
        "reference_run_count": len(reference_runs),
        "candidate_environments": [folder.name for folder in candidate_folders],
        "policy_file": policy_output.as_posix(),
        "policy_sha256": policy.get("policy_sha256") or sha256_json(policy),
        "repeatability_summaries": {
            name: {
                "run_count": analysis.get("run_count"),
                "overall_classification": analysis.get("overall_classification"),
                "environment_representative_run": analysis.get("environment_representative_run"),
                "summary": analysis.get("summary"),
            }
            for name, analysis in analyses.items()
        },
        "retained_all_pair_details": bool(args.retain_all_pairs),
        "environments": environment_results,
    }
    plots: list[Path] = []
    plot_details: list[dict[str, Any]] = []
    if not args.no_plots:
        plots.extend(make_plots(result, output_directory))
        plot_details.extend(
            make_detailed_model_plots(
                runs_by_environment,
                analyses,
                reference_folder.name,
                output_directory,
                policy,
                verify_hash=not args.skip_artifact_hash_check,
            )
        )
        plots.extend(output_directory / item["path"] for item in plot_details)
    result["plots"] = [path.name for path in plots]
    result["plot_details"] = plot_details
    json_path = output_directory / "comparison_results.json"
    markdown_path = output_directory / "comparison_results.md"
    write_json(json_path, result)
    write_markdown(result, markdown_path, plots, plot_details)

    print(f"Reference environment: {reference_folder.name} ({len(reference_runs)} runs)")
    print(f"Compared {len(environment_results)} candidate environments")
    print(f"Populated policy: {policy_output}")
    print(f"JSON: {json_path}")
    print(f"Markdown: {markdown_path}")
    return 1 if any(item["overall_status"] == "FAIL" for item in environment_results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
