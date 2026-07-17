#!/usr/bin/env python3
"""Compare repeatability-analysis JSON files against ``reference.json``.

The default input directory is ``repeatability_outputs`` beneath the current
working directory. This script compares the *quality of repeatability* and can
also prove cross-environment equality where the representative values or tensor
hashes match exactly. A changed floating-point tensor hash cannot be judged for
numerical closeness from analysis JSON alone, so that result is marked MAYBE and
left for ``compare_environment_outputs.py``, which reads the raw artefacts.
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

from comparison_graphs import make_summary_model_plots  # noqa: E402
from comparison_policy import (  # noqa: E402
    BUILTIN_TEMPLATE_PATH,
    combine_statuses,
    compare_analysis_metadata,
    judge_numeric_metrics,
    judge_repeatability_leaf,
    load_policy_template,
    resolve_leaf_policy,
    sha256_json,
    write_json,
)


RESULT_FORMAT_VERSION = "repeatability_comparison_v1"
DEFAULT_INPUT_DIRECTORY = Path("repeatability_outputs")
DEFAULT_OUTPUT_DIRECTORY_NAME = "repeatability_comparison"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input_directory",
        nargs="?",
        type=Path,
        default=DEFAULT_INPUT_DIRECTORY,
        help="Directory containing reference.json and candidate analysis JSON files",
    )
    parser.add_argument(
        "--policy",
        type=Path,
        help=(
            "Populated comparison policy. Defaults to comparison_policy.json beside "
            "this script, then the template if that file does not exist"
        ),
    )
    parser.add_argument("--output-directory", type=Path)
    parser.add_argument("--no-plots", action="store_true")
    return parser.parse_args()


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RuntimeError(f"Required file is missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"File is not valid JSON: {path}") from exc


def default_policy_path() -> Path:
    populated = SCRIPT_DIRECTORY / "comparison_policy.json"
    return populated if populated.is_file() else BUILTIN_TEMPLATE_PATH


def discover_analyses(input_directory: Path) -> tuple[Path, list[Path]]:
    reference = input_directory / "reference.json"
    if not reference.is_file():
        raise RuntimeError(f"Reference analysis is missing: {reference}")
    candidates = []
    for path in sorted(input_directory.glob("*.json")):
        if not path.is_file() or path.name == "reference.json":
            continue
        try:
            value = read_json(path)
        except RuntimeError:
            continue
        if isinstance(value, Mapping) and value.get("analysis_kind") == "intra_environment_repeatability":
            candidates.append(path)
    if not candidates:
        raise RuntimeError(f"No candidate JSON files found beneath {input_directory}")
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


def representative_value(leaf: Mapping[str, Any]) -> Any:
    run = leaf.get("representative_run")
    runs = leaf.get("runs")
    if isinstance(runs, Mapping) and run in runs:
        return runs[run]
    return None


def scalar_cross_metrics(left: float, right: float, limits: Mapping[str, Any]) -> dict[str, Any]:
    left_value = float(left)
    right_value = float(right)
    absolute = abs(left_value - right_value)
    denominator = max(abs(left_value), abs(right_value), np.finfo(np.float64).tiny)
    relative = absolute / denominator
    threshold = float(limits.get("atol", 0.0)) + float(limits.get("rtol", 0.0)) * denominator
    return {
        "comparable": True,
        "maximum_absolute_error": absolute,
        "maximum_symmetric_relative_error": relative,
        "relative_l2_error": relative,
        "maximum_scaled_error": absolute / max(threshold, np.finfo(np.float64).tiny),
        "bad_fraction": 0.0 if absolute <= threshold else 1.0,
        "nan_mask_mismatch_count": 0,
        "infinity_mask_mismatch_count": 0,
        "finite_mask_mismatch_count": 0,
    }


def exact_value_matches(left: Any, right: Any) -> bool:
    return json.dumps(left, sort_keys=True, separators=(",", ":")) == json.dumps(
        right, sort_keys=True, separators=(",", ":")
    )


def compare_representative_leaf(
    reference_leaf: Mapping[str, Any],
    candidate_leaf: Mapping[str, Any],
    leaf_policy: Mapping[str, Any],
    family: Mapping[str, Any],
    *,
    maybe_multiplier: float,
) -> dict[str, Any]:
    reference_value = representative_value(reference_leaf)
    candidate_value = representative_value(candidate_leaf)
    if reference_value is None or candidate_value is None:
        return {"status": "NA", "reason": "representative value is missing"}

    if family.get("comparison_type") == "exact":
        matches = exact_value_matches(reference_value, candidate_value)
        return {
            "status": "PASS" if matches else "FAIL",
            "reason": "representative values match exactly" if matches else "exact representative values differ",
        }

    if reference_leaf.get("value_type") == "numeric_scalar":
        metrics = scalar_cross_metrics(
            float(reference_value),
            float(candidate_value),
            leaf_policy.get("limits", {}).get("cross_environment", {}),
        )
        status, ratios, reason = judge_numeric_metrics(
            metrics,
            leaf_policy.get("limits", {}).get("cross_environment", {}),
            maybe_multiplier=maybe_multiplier,
            require_exceptional_masks_match=bool(
                family.get("require_exceptional_value_masks_match", True)
            ),
        )
        return {"status": status, "reason": reason, "metrics": metrics, "limit_ratios": ratios}

    if isinstance(reference_value, Mapping) and isinstance(candidate_value, Mapping):
        same_metadata = all(
            reference_value.get(name) == candidate_value.get(name)
            for name in ("logical_dtype", "shape", "numel")
        )
        if not same_metadata:
            return {"status": "FAIL", "reason": "representative tensor metadata differs"}
        if reference_value.get("sha256") == candidate_value.get("sha256"):
            return {"status": "PASS", "reason": "representative tensor hashes match exactly"}
        return {
            "status": "MAYBE",
            "reason": "tensor hashes differ and analysis JSON does not contain the raw values",
        }

    return {"status": "MAYBE", "reason": "numeric representative cannot be compared from this JSON"}


def compare_output(
    identity_key: str,
    reference_output: Mapping[str, Any] | None,
    candidate_output: Mapping[str, Any] | None,
    policy: Mapping[str, Any],
) -> dict[str, Any]:
    if reference_output is None or candidate_output is None:
        return {
            "identity_key": identity_key,
            "status": "FAIL",
            "reason": "output is missing from the reference or candidate analysis",
        }
    if reference_output.get("kind") != candidate_output.get("kind"):
        return {
            "identity_key": identity_key,
            "identity": reference_output.get("identity"),
            "level": reference_output.get("level"),
            "category": reference_output.get("category"),
            "importance": reference_output.get("importance"),
            "status": "FAIL",
            "reason": "output kinds differ between reference and candidate",
        }
    output_policy = policy.get("output_policies", {}).get(identity_key)
    if not isinstance(output_policy, Mapping):
        return {
            "identity_key": identity_key,
            "identity": reference_output.get("identity"),
            "level": reference_output.get("level"),
            "category": reference_output.get("category"),
            "importance": reference_output.get("importance"),
            "status": "NA",
            "reason": "no populated output policy is available",
        }

    settings = policy.get("settings", {})
    maybe_multiplier = float(settings.get("maybe_limit_multiplier", 1.5))
    minimum_reference_runs = int(settings.get("minimum_reference_runs", 3))
    minimum_candidate_runs = int(settings.get("minimum_candidate_runs", 3))
    reference_leaves = leaf_map(reference_output)
    candidate_leaves = leaf_map(candidate_output)
    leaf_results: list[dict[str, Any]] = []
    all_paths = sorted(set(reference_leaves) | set(candidate_leaves) | set(output_policy.get("leaves", {})))

    for path in all_paths:
        reference_leaf = reference_leaves.get(path)
        candidate_leaf = candidate_leaves.get(path)
        if reference_leaf is None or candidate_leaf is None:
            leaf_results.append({"path": path, "status": "FAIL", "reason": "leaf is missing"})
            continue
        try:
            leaf_policy, family = resolve_leaf_policy(policy, identity_key, path)
        except KeyError as exc:
            leaf_results.append({"path": path, "status": "NA", "reason": str(exc)})
            continue
        ref_status, ref_reason, ref_ratios = judge_repeatability_leaf(
            reference_leaf,
            leaf_policy,
            family,
            maybe_multiplier=maybe_multiplier,
        )
        cand_status, cand_reason, cand_ratios = judge_repeatability_leaf(
            candidate_leaf,
            leaf_policy,
            family,
            maybe_multiplier=maybe_multiplier,
        )
        representative = compare_representative_leaf(
            reference_leaf,
            candidate_leaf,
            leaf_policy,
            family,
            maybe_multiplier=maybe_multiplier,
        )
        status = combine_statuses([ref_status, cand_status, str(representative["status"])])
        leaf_results.append(
            {
                "path": path,
                "policy_id": leaf_policy.get("policy_id"),
                "status": status,
                "reference_repeatability": {"status": ref_status, "reason": ref_reason, "limit_ratios": ref_ratios},
                "candidate_repeatability": {"status": cand_status, "reason": cand_reason, "limit_ratios": cand_ratios},
                "representative_comparison": representative,
            }
        )

    statuses = [str(item.get("status")) for item in leaf_results]
    status = combine_statuses(statuses)
    run_count_note = None
    if int(reference_output and len(reference_output.get("available_runs", []))) < minimum_reference_runs:
        status = combine_statuses([status, "MAYBE"])
        run_count_note = "reference has fewer runs than the policy recommends"
    if int(candidate_output and len(candidate_output.get("available_runs", []))) < minimum_candidate_runs:
        status = combine_statuses([status, "MAYBE"])
        run_count_note = "candidate has fewer runs than the policy recommends"

    return {
        "identity_key": identity_key,
        "identity": reference_output.get("identity"),
        "level": reference_output.get("level"),
        "category": reference_output.get("category"),
        "importance": reference_output.get("importance"),
        "status": status,
        "run_count_note": run_count_note,
        "leaf_results": leaf_results,
    }


def compare_candidate(
    name: str,
    reference: Mapping[str, Any],
    candidate: Mapping[str, Any],
    policy: Mapping[str, Any],
) -> dict[str, Any]:
    metadata = compare_analysis_metadata(reference, candidate)
    reference_outputs = output_map(reference)
    candidate_outputs = output_map(candidate)
    keys = sorted(set(reference_outputs) | set(candidate_outputs))
    outputs = [
        compare_output(key, reference_outputs.get(key), candidate_outputs.get(key), policy)
        for key in keys
    ]
    required = [item for item in outputs if item.get("importance") == "required"]
    overall = combine_statuses([str(item.get("status")) for item in required or outputs])
    if not metadata["compatible"]:
        overall = "FAIL"
    counts = Counter(str(item.get("status")) for item in outputs)
    by_level: dict[str, Counter[str]] = defaultdict(Counter)
    for item in outputs:
        by_level[str(item.get("level"))][str(item.get("status"))] += 1
    return {
        "candidate": name,
        "overall_status": overall,
        "metadata_compatibility": metadata,
        "status_counts": dict(sorted(counts.items())),
        "level_status_counts": {
            level: dict(sorted(values.items())) for level, values in sorted(by_level.items())
        },
        "outputs": outputs,
    }


def format_value(value: Any) -> str:
    if value is None:
        return "—"
    if isinstance(value, float):
        return f"{value:.3e}" if value and (abs(value) < 1e-3 or abs(value) >= 1e3) else f"{value:.6g}"
    return str(value)


def write_markdown(
    result: Mapping[str, Any],
    path: Path,
    plot_paths: Sequence[Path],
    plot_details: Sequence[Mapping[str, Any]],
) -> None:
    lines = [
        "# Repeatability-analysis comparison",
        "",
        "| Candidate | Overall | PASS | MAYBE | FAIL | NA |",
        "|---|---|---:|---:|---:|---:|",
    ]
    for candidate in result.get("candidates", []):
        counts = candidate.get("status_counts", {})
        lines.append(
            f"| {candidate['candidate']} | **{candidate['overall_status']}** | "
            f"{counts.get('PASS', 0)} | {counts.get('MAYBE', 0)} | "
            f"{counts.get('FAIL', 0)} | {counts.get('NA', 0)} |"
        )

    lines.extend(
        [
            "",
            "`MAYBE` commonly means that repeatability is acceptable but a representative tensor hash changed. "
            "The raw tensor values are needed before numerical closeness can be judged",
        ]
    )

    levels = sorted(
        {
            str(output.get("level"))
            for candidate in result.get("candidates", [])
            for output in candidate.get("outputs", [])
        }
    )
    candidate_names = [str(item["candidate"]) for item in result.get("candidates", [])]
    for level in levels:
        lines.extend(["", f"## {level}", ""])
        headers = " | ".join(["Test / case / profile / output", *candidate_names])
        lines.append(f"| {headers} |")
        lines.append("|" + "---|" * (len(candidate_names) + 1))
        identities: dict[str, Mapping[str, Any]] = {}
        values: dict[tuple[str, str], str] = {}
        for candidate in result.get("candidates", []):
            for output in candidate.get("outputs", []):
                if str(output.get("level")) != level:
                    continue
                key = str(output.get("identity_key"))
                identities[key] = output.get("identity", {})
                values[(str(candidate["candidate"]), key)] = str(output.get("status"))
        for key in sorted(identities):
            identity = identities[key]
            label = " / ".join(
                str(identity.get(name))
                for name in ("test_id", "case_id", "profile_id", "output_id")
            )
            cells = [label, *[values.get((name, key), "NA") for name in candidate_names]]
            lines.append("| " + " | ".join(cells) + " |")

    if plot_paths:
        lines.extend(["", "## Graphs", ""])
        details_by_path = {str(item.get("path")): item for item in plot_details}
        for plot in plot_paths:
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

    candidates = result.get("candidates", [])
    if not candidates:
        return []
    names = [str(item["candidate"]) for item in candidates]
    statuses = ["PASS", "MAYBE", "FAIL", "NA"]
    positions = np.arange(len(names))
    bottom = np.zeros(len(names), dtype=np.int64)
    figure, axis = plt.subplots(figsize=(max(8, len(names) * 1.25), 5.5))
    for status in statuses:
        values = np.asarray([item.get("status_counts", {}).get(status, 0) for item in candidates])
        axis.bar(positions, values, bottom=bottom, label=status)
        bottom += values
    axis.set_xticks(positions)
    axis.set_xticklabels(names, rotation=35, ha="right")
    axis.set_ylabel("Compared output count")
    axis.legend(title="Comparison status")
    axis.grid(True, axis="y", alpha=0.25)
    figure.suptitle(
        "Repeatability-analysis comparison status",
        fontsize=12,
        fontweight="bold",
        y=0.985,
    )
    figure.text(
        0.5,
        0.012,
        "PASS is within policy, FAIL exceeds policy or has a structural problem, MAYBE reflects "
        "insufficient summary detail, and NA could not be compared.",
        ha="center",
        va="bottom",
        fontsize=8.5,
        wrap=True,
    )
    figure.tight_layout(rect=(0.0, 0.065, 1.0, 0.94))
    path = output_directory / "repeatability_comparison_status.png"
    figure.savefig(path, dpi=160)
    plt.close(figure)
    return [path]


def main() -> int:
    args = parse_args()
    input_directory = args.input_directory.resolve()
    output_directory = (
        args.output_directory.resolve()
        if args.output_directory
        else input_directory / DEFAULT_OUTPUT_DIRECTORY_NAME
    )
    output_directory.mkdir(parents=True, exist_ok=True)

    reference_path, candidate_paths = discover_analyses(input_directory)
    reference = read_json(reference_path)
    policy_path = args.policy.resolve() if args.policy else default_policy_path()
    policy = load_policy_template(policy_path)
    if not policy.get("output_policies"):
        raise RuntimeError(
            f"The comparison policy is not populated: {policy_path}. "
            "Run analyse_repeatability.py with --write-populated-policy first"
        )

    candidate_analyses = {path.stem: read_json(path) for path in candidate_paths}
    candidates = [
        compare_candidate(name, reference, analysis, policy)
        for name, analysis in candidate_analyses.items()
    ]
    result = {
        "comparison_format_version": RESULT_FORMAT_VERSION,
        "comparison_kind": "repeatability_analysis_comparison",
        "reference_file": reference_path.name,
        "candidate_files": [path.name for path in candidate_paths],
        "policy_file": policy_path.as_posix(),
        "policy_sha256": policy.get("policy_sha256") or sha256_json(policy),
        "candidates": candidates,
    }
    plot_paths: list[Path] = []
    plot_details: list[dict[str, Any]] = []
    if not args.no_plots:
        plot_paths.extend(make_plots(result, output_directory))
        plot_details.extend(
            make_summary_model_plots(
                reference,
                candidate_analyses,
                output_directory,
                policy,
            )
        )
        plot_paths.extend(output_directory / item["path"] for item in plot_details)
    result["plots"] = [path.name for path in plot_paths]
    result["plot_details"] = plot_details
    json_path = output_directory / "repeatability_comparison_results.json"
    markdown_path = output_directory / "repeatability_comparison_results.md"
    write_json(json_path, result)
    write_markdown(result, markdown_path, plot_paths, plot_details)

    print(f"Compared {len(candidates)} repeatability analyses")
    print(f"JSON: {json_path}")
    print(f"Markdown: {markdown_path}")
    return 1 if any(item["overall_status"] == "FAIL" for item in candidates) else 0


if __name__ == "__main__":
    raise SystemExit(main())
