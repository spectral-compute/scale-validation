"""Write the concise CSV produced by the Level 0 demonstration run."""

from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any, Iterable, Mapping

from config.suite_config import LEVEL_0_DEMOS


CSV_FIELDS = (
    "test_id",
    "case_id",
    "profile_id",
    "status",
    "reason",
    "model_type",
    "optimiser",
    "training_steps",
    "device",
    "dtype",
    "sample_count",
    "class_count",
    "initial_loss",
    "final_loss",
    "loss_change",
    "initial_accuracy",
    "final_accuracy",
    "prediction_changes",
    "initial_predictions",
    "final_predictions",
    "initial_logits_mean",
    "initial_logits_standard_deviation",
    "initial_logits_maximum_absolute",
    "final_logits_mean",
    "final_logits_standard_deviation",
    "final_logits_maximum_absolute",
    "first_gradient_l2",
    "initial_parameter_l2",
    "final_parameter_l2",
    "activation_count",
    "activation_mean_absolute",
    "activation_maximum_absolute",
    "activation_names",
)


def _format_value(value: Any) -> Any:
    if isinstance(value, list):
        return " ".join(str(item) for item in value)
    if value is None:
        return ""
    return value


def _summary_payloads(path: Path) -> dict[tuple[str, str, str], Mapping[str, Any]]:
    output: dict[tuple[str, str, str], Mapping[str, Any]] = {}
    if not path.is_file():
        return output
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        if record.get("output_id") != "summary" or record.get("status") != "produced":
            continue
        payload = record.get("payload")
        if isinstance(payload, Mapping):
            key = (
                str(record.get("test_id")),
                str(record.get("case_id")),
                str(record.get("profile_id")),
            )
            output[key] = payload
    return output


def write_level_0_summary(
    results_root: Path,
    task_records: Iterable[Mapping[str, Any]],
) -> Path | None:
    """Write one row per Level 0 example/profile when Level 0 was selected."""

    level_0_tasks = [
        task for task in task_records if task.get("test_id") == "demo.model_workloads"
    ]
    if not level_0_tasks:
        return None

    summaries = _summary_payloads(results_root / "observations.jsonl")
    rows: list[dict[str, Any]] = []
    for task in level_0_tasks:
        test_id = str(task.get("test_id"))
        profile_id = str(task.get("profile_id"))
        for case in task.get("case_records", []):
            case_id = str(case.get("case_id"))
            row: dict[str, Any] = {
                "test_id": test_id,
                "case_id": case_id,
                "profile_id": profile_id,
                "status": case.get("status", "unknown"),
                "reason": case.get("reason") or "",
            }
            payload = summaries.get((test_id, case_id, profile_id), {})
            row.update(payload)
            rows.append({field: _format_value(row.get(field)) for field in CSV_FIELDS})

    path = results_root / str(LEVEL_0_DEMOS["summary_filename"])
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    return path
