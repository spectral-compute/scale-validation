#!/usr/bin/env python3
"""Inspect and validate one raw result bundle written by the suite."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = REPOSITORY_ROOT / "src"
for path in (REPOSITORY_ROOT, SRC_ROOT):
    value = str(path)
    if value not in sys.path:
        sys.path.insert(0, value)

from config.suite_config import RESULTS_DIR  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("result_directory", nargs="?", type=Path, default=RESULTS_DIR)
    parser.add_argument(
        "--skip-artifact-hashes",
        action="store_true",
        help="Check that artifacts exist but do not recalculate their SHA-256 hashes",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print the inspection summary as JSON",
    )
    return parser.parse_args()


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RuntimeError(f"Required result file is missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Result file is not valid JSON: {path}") from exc


def read_json_lines(path: Path) -> list[dict[str, Any]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError as exc:
        raise RuntimeError(f"Required result file is missing: {path}") from exc

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


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def iter_tensor_descriptors(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        if value.get("artifact_type") == "tensor":
            yield value
            return
        for item in value.values():
            yield from iter_tensor_descriptors(item)
    elif isinstance(value, list):
        for item in value:
            yield from iter_tensor_descriptors(item)


def inspect_artifacts(
    result_directory: Path,
    observations: list[dict[str, Any]],
    *,
    verify_hashes: bool,
) -> dict[str, Any]:
    descriptor_count = 0
    total_bytes = 0
    seen_paths: set[str] = set()

    for observation in observations:
        for descriptor in iter_tensor_descriptors(observation.get("payload")):
            descriptor_count += 1
            relative_path = descriptor.get("relative_path")
            if not isinstance(relative_path, str):
                raise RuntimeError("Tensor descriptor has no relative_path")
            if relative_path in seen_paths:
                raise RuntimeError(f"Tensor artifact is referenced more than once: {relative_path}")
            seen_paths.add(relative_path)

            path = result_directory / relative_path
            if not path.is_file():
                raise RuntimeError(f"Tensor artifact is missing: {path}")
            expected_length = descriptor.get("byte_length")
            if path.stat().st_size != expected_length:
                raise RuntimeError(f"Tensor artifact size does not match its descriptor: {path}")
            total_bytes += path.stat().st_size

            if verify_hashes:
                expected_hash = descriptor.get("sha256")
                if hash_file(path) != expected_hash:
                    raise RuntimeError(f"Tensor artifact hash does not match: {path}")

    artifact_files = {
        path.relative_to(result_directory).as_posix()
        for path in (result_directory / "artifacts").rglob("*.bin")
    }
    unreferenced = sorted(artifact_files - seen_paths)
    if unreferenced:
        raise RuntimeError(
            "The bundle contains unreferenced tensor artifacts\n"
            + "\n".join(unreferenced[:20])
        )

    return {
        "tensor_descriptor_count": descriptor_count,
        "tensor_artifact_count": len(artifact_files),
        "tensor_artifact_bytes": total_bytes,
        "hashes_verified": verify_hashes,
    }


def main() -> int:
    args = parse_args()
    result_directory = args.result_directory.resolve()
    manifest = read_json(result_directory / "run_manifest.json")
    status = read_json(result_directory / "test_status.json")
    observations = read_json_lines(result_directory / "observations.jsonl")

    tasks = status.get("tasks") if isinstance(status, dict) else None
    if not isinstance(tasks, list):
        raise RuntimeError("test_status.json does not contain a tasks list")

    task_statuses = Counter(str(task.get("status", "unknown")) for task in tasks)
    observation_statuses = Counter(
        str(observation.get("status", "unknown")) for observation in observations
    )
    output_kinds = Counter(str(observation.get("kind", "unknown")) for observation in observations)
    artifact_summary = inspect_artifacts(
        result_directory,
        observations,
        verify_hashes=not args.skip_artifact_hashes,
    )

    level_0_tasks = [task for task in tasks if task.get("test_id") == "demo.model_workloads"]
    level_0_summary_rows = 0
    if level_0_tasks:
        summary_path = result_directory / "level_0_summary.csv"
        if not summary_path.is_file():
            raise RuntimeError("Level 0 ran but level_0_summary.csv is missing")
        with summary_path.open("r", encoding="utf-8", newline="") as source:
            level_0_summary_rows = sum(1 for _ in csv.DictReader(source))
        expected_rows = sum(len(task.get("case_records", [])) for task in level_0_tasks)
        if level_0_summary_rows != expected_rows:
            raise RuntimeError(
                "level_0_summary.csv row count does not match the Level 0 case count"
            )

    summary = {
        "status": "valid",
        "result_directory": result_directory.as_posix(),
        "suite_name": manifest.get("suite_name"),
        "suite_version": manifest.get("suite_version"),
        "overall_execution_status": manifest.get("overall_execution_status"),
        "planned_task_count": manifest.get("planned_task_count"),
        "task_count": len(tasks),
        "task_statuses": dict(sorted(task_statuses.items())),
        "observation_count": len(observations),
        "observation_statuses": dict(sorted(observation_statuses.items())),
        "output_kinds": dict(sorted(output_kinds.items())),
        "level_0_summary_rows": level_0_summary_rows,
        **artifact_summary,
    }

    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print("Result bundle is valid")
        print(f"Directory: {result_directory}")
        print(f"Execution status: {summary['overall_execution_status']}")
        print(f"Tasks: {len(tasks)} {dict(task_statuses)}")
        print(f"Observations: {len(observations)} {dict(observation_statuses)}")
        print(f"Tensor artifacts: {artifact_summary['tensor_artifact_count']}")
        print(f"Tensor bytes: {artifact_summary['tensor_artifact_bytes']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
