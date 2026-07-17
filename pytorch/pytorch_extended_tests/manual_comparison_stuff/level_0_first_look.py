#!/usr/bin/env python3
"""Collate and roughly compare Level 0 summary CSV files.

USAGE
=====

1. Create a folder named ``level_0_summaries`` beside the repository root, or
   pass another folder as the first positional argument

2. Put one ``level_0_summary.csv`` result from each CI environment in that
   folder and rename each file to describe the environment, for example::

       level_0_summaries/
       ├── reference.csv
       ├── gcc_a100.csv
       ├── clang_a100.csv
       └── gcc_h100.csv

   The reference file must have the stem ``reference``. The match is
   case-insensitive, so ``Reference.csv`` also works

3. Run::

       python manual_comparison_stuff/level_0_first_look.py

   Or pass a different input directory::

       python manual_comparison_stuff/level_0_first_look.py path/to/level_0_summaries

The script writes two files into the input directory unless ``--output-dir``
is supplied:

``level_0_first_look_collated.md``
    One table per example and precision profile. Each input CSV is one column,
    using the CSV filename as the column heading

``level_0_first_look_summary.md``
    A deliberately rough PASS, FAIL or MAYBE comparison against reference.csv

This is only a first look. It compares the small scalar summaries and prediction
previews, not the complete tensor artefacts. PASS does not prove numerical
compatibility, and MAYBE is meant to prompt inspection of the raw artefacts
rather than being treated as a failure

The thresholds are intentionally broad and profile-aware. FP16 and BF16 receive
more room than FP32, and later training values receive more room than the initial
forward pass. The future full comparison harness should replace these heuristics
with the versioned per-output policies and repeatability analysis

The process exits with code 1 when any candidate has an overall FAIL result,
code 2 for invalid input, and code 0 otherwise
"""

from __future__ import annotations

import argparse
import csv
import math
import sys
from dataclasses import dataclass
from enum import IntEnum
from pathlib import Path
from typing import Iterable, Mapping


DEFAULT_INPUT_DIRECTORY = Path("level_0_summaries")
COLLATED_FILENAME = "level_0_first_look_collated.md"
SUMMARY_FILENAME = "level_0_first_look_summary.md"
IDENTITY_FIELDS = ("test_id", "case_id", "profile_id")
IGNORED_COMPARISON_FIELDS = {"device", "reason"}
EXACT_FIELDS = {
    "model_type",
    "optimiser",
    "training_steps",
    "dtype",
    "sample_count",
    "class_count",
    "activation_count",
    "activation_names",
}
PREDICTION_FIELDS = {"initial_predictions", "final_predictions"}
ACCURACY_FIELDS = {"initial_accuracy", "final_accuracy"}
LATER_TRAINING_FIELDS = {
    "final_loss",
    "loss_change",
    "final_logits_mean",
    "final_logits_standard_deviation",
    "final_logits_maximum_absolute",
    "final_parameter_l2",
}


class Verdict(IntEnum):
    """Ordered verdict so the worst result wins cleanly."""

    PASS = 0
    MAYBE = 1
    FAIL = 2

    @property
    def label(self) -> str:
        return self.name


@dataclass(frozen=True, slots=True)
class Tolerance:
    """Tight and loose scalar limits for one execution profile."""

    tight_relative: float
    tight_absolute: float
    loose_relative: float
    loose_absolute: float


@dataclass(frozen=True, slots=True)
class CsvRun:
    """One parsed Level 0 summary CSV."""

    path: Path
    fieldnames: tuple[str, ...]
    rows: Mapping[tuple[str, str, str], Mapping[str, str]]

    @property
    def name(self) -> str:
        return self.path.name


@dataclass(frozen=True, slots=True)
class RowComparison:
    """Rough comparison for one example/profile row."""

    verdict: Verdict
    reasons: tuple[str, ...]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input_directory",
        nargs="?",
        type=Path,
        default=DEFAULT_INPUT_DIRECTORY,
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        help="Write the two Markdown files somewhere other than the input directory",
    )
    return parser.parse_args()


def _normalise_cell(value: str | None) -> str:
    return "" if value is None else value.strip()


def load_csv(path: Path) -> CsvRun:
    try:
        with path.open("r", encoding="utf-8", newline="") as source:
            reader = csv.DictReader(source)
            if reader.fieldnames is None:
                raise ValueError("the CSV has no header")
            fieldnames = tuple(_normalise_cell(name) for name in reader.fieldnames)
            missing_identity = set(IDENTITY_FIELDS) - set(fieldnames)
            if missing_identity:
                raise ValueError(
                    f"the CSV is missing identity fields: {sorted(missing_identity)}"
                )

            rows: dict[tuple[str, str, str], Mapping[str, str]] = {}
            for line_number, raw_row in enumerate(reader, start=2):
                row = {str(key): _normalise_cell(value) for key, value in raw_row.items()}
                key = tuple(row[field] for field in IDENTITY_FIELDS)
                if any(not part for part in key):
                    raise ValueError(f"line {line_number} has an empty row identity")
                if key in rows:
                    raise ValueError(
                        f"line {line_number} duplicates row identity {key!r}"
                    )
                rows[key] = row
    except OSError as exc:
        raise ValueError(f"could not read {path}: {exc}") from exc

    if not rows:
        raise ValueError(f"{path} contains no result rows")
    return CsvRun(path=path, fieldnames=fieldnames, rows=rows)


def discover_runs(input_directory: Path) -> tuple[CsvRun, tuple[CsvRun, ...]]:
    if not input_directory.is_dir():
        raise ValueError(f"input directory does not exist: {input_directory}")

    paths = sorted(input_directory.glob("*.csv"), key=lambda item: item.name.lower())
    if not paths:
        raise ValueError(f"no CSV files were found in {input_directory}")

    reference_paths = [path for path in paths if path.stem.lower() == "reference"]
    if len(reference_paths) != 1:
        raise ValueError(
            "the input directory must contain exactly one CSV with the stem 'reference'"
        )

    reference = load_csv(reference_paths[0])
    candidates = tuple(load_csv(path) for path in paths if path != reference_paths[0])
    return reference, candidates


def _markdown(value: object) -> str:
    text = "—" if value is None or str(value) == "" else str(value)
    return text.replace("|", "\\|").replace("\n", "<br>")


def _heading_for_key(key: tuple[str, str, str]) -> str:
    test_id, case_id, profile_id = key
    return f"{case_id} — {profile_id}"


def _ordered_row_keys(runs: Iterable[CsvRun], reference: CsvRun) -> tuple[tuple[str, str, str], ...]:
    ordered = list(reference.rows)
    known = set(ordered)
    for run in runs:
        for key in run.rows:
            if key not in known:
                ordered.append(key)
                known.add(key)
    return tuple(ordered)


def _ordered_fields(runs: Iterable[CsvRun], reference: CsvRun) -> tuple[str, ...]:
    ordered = [field for field in reference.fieldnames if field not in IDENTITY_FIELDS]
    known = set(ordered)
    for run in runs:
        for field in run.fieldnames:
            if field not in IDENTITY_FIELDS and field not in known:
                ordered.append(field)
                known.add(field)
    return tuple(ordered)


def write_collated(
    path: Path,
    *,
    reference: CsvRun,
    candidates: tuple[CsvRun, ...],
) -> None:
    runs = (reference, *candidates)
    row_keys = _ordered_row_keys(runs, reference)
    fields = _ordered_fields(runs, reference)

    lines = [
        "# Level 0 first-look collated results",
        "",
        "Each input CSV is shown as one column. Missing rows or fields are shown as —",
        "",
    ]
    for key in row_keys:
        lines.extend(
            [
                f"## {_markdown(_heading_for_key(key))}",
                "",
                "| Metric | " + " | ".join(_markdown(run.name) for run in runs) + " |",
                "|---|" + "---|" * len(runs),
            ]
        )
        for field in fields:
            values = []
            for run in runs:
                row = run.rows.get(key)
                values.append(None if row is None else row.get(field, ""))
            lines.append(
                f"| {_markdown(field)} | "
                + " | ".join(_markdown(value) for value in values)
                + " |"
            )
        lines.append("")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def _profile_tolerance(profile_id: str, *, later_training: bool) -> Tolerance:
    normalised = profile_id.lower()
    if "bfloat16" in normalised:
        tolerance = Tolerance(2e-2, 2e-3, 1e-1, 1e-2)
    elif "fp16" in normalised:
        tolerance = Tolerance(8e-3, 5e-4, 5e-2, 3e-3)
    elif "fp64" in normalised:
        tolerance = Tolerance(1e-8, 1e-10, 1e-6, 1e-8)
    else:
        tolerance = Tolerance(2e-4, 2e-6, 3e-3, 3e-5)

    if not later_training:
        return tolerance
    return Tolerance(
        tight_relative=tolerance.tight_relative * 2,
        tight_absolute=tolerance.tight_absolute * 2,
        loose_relative=tolerance.loose_relative * 2,
        loose_absolute=tolerance.loose_absolute * 2,
    )


def _parse_float(value: str, *, field: str) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise ValueError(f"{field} is not numeric: {value!r}") from exc
    if not math.isfinite(parsed):
        raise ValueError(f"{field} is not finite: {value!r}")
    return parsed


def _within(actual: float, reference: float, *, relative: float, absolute: float) -> bool:
    return abs(actual - reference) <= absolute + relative * abs(reference)


def _compare_numeric(
    field: str,
    reference_value: str,
    candidate_value: str,
    *,
    profile_id: str,
) -> RowComparison:
    try:
        reference_number = _parse_float(reference_value, field=field)
        candidate_number = _parse_float(candidate_value, field=field)
    except ValueError as exc:
        return RowComparison(Verdict.FAIL, (str(exc),))

    tolerance = _profile_tolerance(
        profile_id,
        later_training=field in LATER_TRAINING_FIELDS,
    )
    if _within(
        candidate_number,
        reference_number,
        relative=tolerance.tight_relative,
        absolute=tolerance.tight_absolute,
    ):
        return RowComparison(Verdict.PASS, ())
    if _within(
        candidate_number,
        reference_number,
        relative=tolerance.loose_relative,
        absolute=tolerance.loose_absolute,
    ):
        return RowComparison(
            Verdict.MAYBE,
            (
                f"{field} differs from reference by "
                f"{candidate_number - reference_number:.6g}",
            ),
        )
    return RowComparison(
        Verdict.FAIL,
        (
            f"{field} is outside the rough limit "
            f"({reference_number:.6g} vs {candidate_number:.6g})",
        ),
    )


def _prediction_values(value: str) -> tuple[str, ...]:
    return tuple(part for part in value.split() if part)


def _compare_prediction_preview(field: str, reference_value: str, candidate_value: str) -> RowComparison:
    reference_predictions = _prediction_values(reference_value)
    candidate_predictions = _prediction_values(candidate_value)
    if len(reference_predictions) != len(candidate_predictions):
        return RowComparison(
            Verdict.FAIL,
            (f"{field} preview length differs from reference",),
        )
    differences = sum(
        reference_item != candidate_item
        for reference_item, candidate_item in zip(
            reference_predictions,
            candidate_predictions,
        )
    )
    if differences == 0:
        return RowComparison(Verdict.PASS, ())
    if differences == 1:
        return RowComparison(
            Verdict.MAYBE,
            (f"{field} differs at one preview position",),
        )
    return RowComparison(
        Verdict.FAIL,
        (f"{field} differs at {differences} preview positions",),
    )


def _compare_accuracy(
    field: str,
    reference_value: str,
    candidate_value: str,
    *,
    sample_count: int,
) -> RowComparison:
    try:
        reference_number = _parse_float(reference_value, field=field)
        candidate_number = _parse_float(candidate_value, field=field)
    except ValueError as exc:
        return RowComparison(Verdict.FAIL, (str(exc),))

    difference = abs(candidate_number - reference_number)
    if difference <= 1e-12:
        return RowComparison(Verdict.PASS, ())
    one_sample = 1.0 / max(sample_count, 1)
    if difference <= 2 * one_sample + 1e-12:
        return RowComparison(
            Verdict.MAYBE,
            (f"{field} differs by {difference:.6g}",),
        )
    return RowComparison(
        Verdict.FAIL,
        (f"{field} differs by {difference:.6g}",),
    )


def _combine(parts: Iterable[RowComparison]) -> RowComparison:
    verdict = Verdict.PASS
    reasons: list[str] = []
    for part in parts:
        verdict = max(verdict, part.verdict)
        reasons.extend(part.reasons)
    return RowComparison(verdict, tuple(reasons))


def compare_rows(
    reference_row: Mapping[str, str],
    candidate_row: Mapping[str, str],
) -> RowComparison:
    profile_id = reference_row["profile_id"]
    parts: list[RowComparison] = []

    if reference_row.get("status") != "passed":
        parts.append(
            RowComparison(
                Verdict.FAIL,
                (f"reference status is {reference_row.get('status') or 'missing'}",),
            )
        )
    if candidate_row.get("status") != "passed":
        parts.append(
            RowComparison(
                Verdict.FAIL,
                (f"candidate status is {candidate_row.get('status') or 'missing'}",),
            )
        )

    for field in sorted(EXACT_FIELDS):
        if field not in reference_row or field not in candidate_row:
            parts.append(RowComparison(Verdict.FAIL, (f"{field} is missing",)))
        elif reference_row[field] != candidate_row[field]:
            parts.append(
                RowComparison(
                    Verdict.FAIL,
                    (f"{field} differs from reference",),
                )
            )

    for field in sorted(PREDICTION_FIELDS):
        if field not in reference_row or field not in candidate_row:
            parts.append(RowComparison(Verdict.FAIL, (f"{field} is missing",)))
        else:
            parts.append(
                _compare_prediction_preview(
                    field,
                    reference_row[field],
                    candidate_row[field],
                )
            )

    try:
        sample_count = int(reference_row.get("sample_count", "0"))
    except ValueError:
        sample_count = 0
    for field in sorted(ACCURACY_FIELDS):
        if field not in reference_row or field not in candidate_row:
            parts.append(RowComparison(Verdict.FAIL, (f"{field} is missing",)))
        else:
            parts.append(
                _compare_accuracy(
                    field,
                    reference_row[field],
                    candidate_row[field],
                    sample_count=sample_count,
                )
            )

    if "prediction_changes" not in reference_row or "prediction_changes" not in candidate_row:
        parts.append(RowComparison(Verdict.FAIL, ("prediction_changes is missing",)))
    else:
        try:
            reference_changes = int(reference_row["prediction_changes"])
            candidate_changes = int(candidate_row["prediction_changes"])
        except ValueError:
            parts.append(
                RowComparison(Verdict.FAIL, ("prediction_changes is not an integer",))
            )
        else:
            difference = abs(candidate_changes - reference_changes)
            loose_difference = max(1, math.ceil(max(sample_count, 1) * 0.05))
            if difference == 0:
                parts.append(RowComparison(Verdict.PASS, ()))
            elif difference <= loose_difference:
                parts.append(
                    RowComparison(
                        Verdict.MAYBE,
                        (f"prediction_changes differs by {difference}",),
                    )
                )
            else:
                parts.append(
                    RowComparison(
                        Verdict.FAIL,
                        (f"prediction_changes differs by {difference}",),
                    )
                )

    handled = (
        set(IDENTITY_FIELDS)
        | IGNORED_COMPARISON_FIELDS
        | EXACT_FIELDS
        | PREDICTION_FIELDS
        | ACCURACY_FIELDS
        | {"status", "prediction_changes"}
    )
    numeric_fields = sorted(
        field
        for field in set(reference_row) | set(candidate_row)
        if field not in handled
    )
    for field in numeric_fields:
        reference_value = reference_row.get(field, "")
        candidate_value = candidate_row.get(field, "")
        if not reference_value or not candidate_value:
            parts.append(RowComparison(Verdict.FAIL, (f"{field} is missing",)))
            continue
        parts.append(
            _compare_numeric(
                field,
                reference_value,
                candidate_value,
                profile_id=profile_id,
            )
        )

    return _combine(parts)


def compare_run(reference: CsvRun, candidate: CsvRun) -> Mapping[tuple[str, str, str], RowComparison]:
    output: dict[tuple[str, str, str], RowComparison] = {}
    all_keys = tuple(dict.fromkeys((*reference.rows, *candidate.rows)))
    for key in all_keys:
        reference_row = reference.rows.get(key)
        candidate_row = candidate.rows.get(key)
        if reference_row is None:
            output[key] = RowComparison(
                Verdict.MAYBE,
                ("candidate has an extra example/profile not present in reference",),
            )
        elif candidate_row is None:
            output[key] = RowComparison(
                Verdict.FAIL,
                ("candidate is missing this reference example/profile",),
            )
        else:
            output[key] = compare_rows(reference_row, candidate_row)
    return output


def _short_reasons(reasons: tuple[str, ...], *, limit: int = 4) -> str:
    if not reasons:
        return "—"
    selected = list(dict.fromkeys(reasons))
    if len(selected) > limit:
        selected = [*selected[:limit], f"and {len(selected) - limit} more"]
    return "; ".join(selected)


def write_summary(
    path: Path,
    *,
    reference: CsvRun,
    candidates: tuple[CsvRun, ...],
) -> bool:
    comparisons = {
        candidate.name: compare_run(reference, candidate)
        for candidate in candidates
    }
    lines = [
        "# Level 0 first-look comparison",
        "",
        f"Reference: `{reference.name}`",
        "",
        "> This is a rough comparison of the summary CSV only. It is not a substitute for comparing the stored tensors or checking repeatability across several runs",
        "",
        "## Overall",
        "",
        "| CSV | Verdict | PASS rows | MAYBE rows | FAIL rows |",
        "|---|---:|---:|---:|---:|",
        f"| {_markdown(reference.name)} | PASS | {len(reference.rows)} | 0 | 0 |",
    ]

    any_fail = False
    for candidate in candidates:
        row_results = comparisons[candidate.name]
        counts = {verdict: 0 for verdict in Verdict}
        for result in row_results.values():
            counts[result.verdict] += 1
        overall = max(
            (result.verdict for result in row_results.values()),
            default=Verdict.FAIL,
        )
        any_fail = any_fail or overall == Verdict.FAIL
        lines.append(
            f"| {_markdown(candidate.name)} | {overall.label} | "
            f"{counts[Verdict.PASS]} | {counts[Verdict.MAYBE]} | "
            f"{counts[Verdict.FAIL]} |"
        )

    if not candidates:
        lines.extend(
            [
                "",
                "No candidate CSV files were found, so only the reference was collated",
            ]
        )
    else:
        lines.extend(
            [
                "",
                "## Per-example results",
                "",
                "| CSV | Example | Profile | Verdict | Main reasons |",
                "|---|---|---|---:|---|",
            ]
        )
        for candidate in candidates:
            for key, result in comparisons[candidate.name].items():
                _, case_id, profile_id = key
                lines.append(
                    f"| {_markdown(candidate.name)} | {_markdown(case_id)} | "
                    f"{_markdown(profile_id)} | {result.verdict.label} | "
                    f"{_markdown(_short_reasons(result.reasons))} |"
                )

    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "- **PASS** means the small summary values are close to the reference under deliberately rough profile-aware thresholds",
            "- **MAYBE** means the result is plausible but different enough that the detailed tensor artefacts should be inspected",
            "- **FAIL** means a row is missing, structurally different, did not pass in CI, or is well outside the rough summary thresholds",
        ]
    )

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    return any_fail


def main() -> int:
    args = parse_args()
    input_directory = args.input_directory.resolve()
    output_directory = (
        args.output_dir.resolve() if args.output_dir is not None else input_directory
    )

    try:
        reference, candidates = discover_runs(input_directory)
        collated_path = output_directory / COLLATED_FILENAME
        summary_path = output_directory / SUMMARY_FILENAME
        write_collated(collated_path, reference=reference, candidates=candidates)
        any_fail = write_summary(
            summary_path,
            reference=reference,
            candidates=candidates,
        )
    except ValueError as exc:
        print(f"level_0_first_look: {exc}", file=sys.stderr)
        return 2

    print(f"Wrote {collated_path}")
    print(f"Wrote {summary_path}")
    return 1 if any_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
