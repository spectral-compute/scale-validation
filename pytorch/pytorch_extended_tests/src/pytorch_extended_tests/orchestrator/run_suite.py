"""Run the configured PyTorch cases and write a raw CI result bundle."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Iterable

from config.suite_config import (
    ALLOWED_DEVICES,
    DATASET_MANIFEST_PATH,
    DEFAULT_DEVICE,
    DEVICE_ENVIRONMENT_VARIABLE,
    EXECUTION,
    EXECUTION_PROFILES,
    RESULTS_DIR,
)
from config.test_catalogue import catalogue_as_dict, get_test_spec
from pytorch_extended_tests.datasets.validation import validate_datasets
from pytorch_extended_tests.orchestrator.execution_plan import build_execution_plan
from pytorch_extended_tests.orchestrator.subprocess_runner import run_task_subprocess
from pytorch_extended_tests.results.result_bundle import ResultBundle


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results-dir", type=Path, default=RESULTS_DIR)
    parser.add_argument("--device", choices=ALLOWED_DEVICES)
    parser.add_argument("--profiles", nargs="+", choices=tuple(EXECUTION_PROFILES))
    parser.add_argument("--levels", nargs="+")
    parser.add_argument("--tests", nargs="+")
    parser.add_argument(
        "--keep-existing",
        action="store_true",
        help="Do not remove the result directory before starting",
    )
    parser.add_argument(
        "--list-plan",
        action="store_true",
        help="Print the selected tasks without running them",
    )
    return parser.parse_args()


def resolve_device(command_line_device: str | None) -> str:
    value = command_line_device or os.environ.get(DEVICE_ENVIRONMENT_VARIABLE) or DEFAULT_DEVICE
    if value not in ALLOWED_DEVICES:
        raise ValueError(
            f"{DEVICE_ENVIRONMENT_VARIABLE} must be one of {', '.join(ALLOWED_DEVICES)}"
        )
    return value


def required_dataset_ids(test_ids: Iterable[str]) -> tuple[str, ...]:
    ordered: list[str] = []
    for test_id in test_ids:
        for dataset_id in get_test_spec(test_id).dataset_ids:
            if dataset_id not in ordered:
                ordered.append(dataset_id)
    return tuple(ordered)


def print_plan(tasks: Iterable[object]) -> None:
    for task in tasks:
        print(f"{task.task_id}: {task.test_id} [{task.profile_id}] on {task.device}")


def main() -> int:
    args = parse_args()
    device = resolve_device(args.device)
    plan = build_execution_plan(
        device=device,
        profiles=args.profiles,
        levels=args.levels,
        test_ids=args.tests,
    )
    if not plan:
        raise RuntimeError("The selected configuration produced an empty execution plan")

    if args.list_plan:
        print_plan(plan)
        return 0

    datasets = required_dataset_ids(task.test_id for task in plan)
    try:
        validate_datasets(
            datasets,
            validate_downloaded_sources=bool(EXECUTION["validate_downloaded_sources"]),
        )
    except Exception as exc:
        args.results_dir.mkdir(parents=True, exist_ok=True)
        (args.results_dir / "preflight_error.json").write_text(
            json.dumps(
                {
                    "status": "failed",
                    "stage": "dataset_validation",
                    "error_type": type(exc).__name__,
                    "message": str(exc),
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"Dataset validation failed: {exc}", file=sys.stderr)
        return 2

    bundle = ResultBundle(
        args.results_dir,
        remove_existing=bool(EXECUTION["remove_existing_results"]) and not args.keep_existing,
    )
    selected_profiles = tuple(dict.fromkeys(task.profile_id for task in plan))
    bundle.write_initial_manifest(
        dataset_manifest_path=DATASET_MANIFEST_PATH,
        device=device,
        profile_ids=selected_profiles,
        planned_task_count=len(plan),
    )
    if EXECUTION["write_catalogue_snapshot"]:
        (args.results_dir / "test_catalogue.json").write_text(
            json.dumps(catalogue_as_dict(), indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    print(f"Running {len(plan)} test/profile tasks on {device}")
    print(f"Writing raw results to {args.results_dir}")

    task_records = []
    try:
        for index, task in enumerate(plan, start=1):
            print(f"\n[{index}/{len(plan)}] {task.test_id} [{task.profile_id}]")
            record = run_task_subprocess(
                task,
                results_root=args.results_dir,
                timeout_seconds=int(EXECUTION["subprocess_timeout_seconds"]),
            )
            task_records.append(record)
            if record.get("status") in {"failed", "timed_out"}:
                print(f"Task failed: {task.test_id} [{task.profile_id}]", file=sys.stderr)
                if not EXECUTION["continue_after_test_file_failure"]:
                    break
    except KeyboardInterrupt:
        print("Suite interrupted", file=sys.stderr)
        overall_status = "failed"
        bundle.finalise(task_records=task_records, overall_status=overall_status)
        return 130

    failed = any(record.get("status") in {"failed", "timed_out"} for record in task_records)
    incomplete = len(task_records) != len(plan)
    overall_status = "failed" if failed or incomplete else "passed"
    bundle.finalise(task_records=task_records, overall_status=overall_status)

    print(f"\nSuite execution status: {overall_status}")
    return 1 if overall_status == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
