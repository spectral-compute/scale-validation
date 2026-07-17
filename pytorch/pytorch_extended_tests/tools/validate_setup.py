#!/usr/bin/env python3
"""Validate the repository, datasets and selected execution plan."""

from __future__ import annotations

import argparse
import importlib
import json
import os
import sys
from pathlib import Path
from typing import Any

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = REPOSITORY_ROOT / "src"
for path in (REPOSITORY_ROOT, SRC_ROOT):
    value = str(path)
    if value not in sys.path:
        sys.path.insert(0, value)

from config.suite_config import (  # noqa: E402
    ALLOWED_DEVICES,
    DEFAULT_DEVICE,
    DEVICE_ENVIRONMENT_VARIABLE,
    EXECUTION,
    EXECUTION_PROFILES,
    validate_suite_config,
)
from config.test_catalogue import get_test_spec, validate_test_catalogue  # noqa: E402
from pytorch_extended_tests.datasets.validation import validate_datasets  # noqa: E402
from pytorch_extended_tests.orchestrator.execution_plan import build_execution_plan  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", choices=ALLOWED_DEVICES)
    parser.add_argument("--profiles", nargs="+", choices=tuple(EXECUTION_PROFILES))
    parser.add_argument("--levels", nargs="+")
    parser.add_argument("--tests", nargs="+")
    parser.add_argument(
        "--skip-downloaded-source-checks",
        action="store_true",
        help="Only validate the prepared files needed by the selected tests",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print the validation summary as JSON",
    )
    return parser.parse_args()


def resolve_device(value: str | None) -> str:
    selected = value or os.environ.get(DEVICE_ENVIRONMENT_VARIABLE) or DEFAULT_DEVICE
    if selected not in ALLOWED_DEVICES:
        raise ValueError(
            f"{DEVICE_ENVIRONMENT_VARIABLE} must be one of {', '.join(ALLOWED_DEVICES)}"
        )
    return selected


def required_dataset_ids(test_ids: list[str]) -> tuple[str, ...]:
    ordered: list[str] = []
    for test_id in test_ids:
        for dataset_id in get_test_spec(test_id).dataset_ids:
            if dataset_id not in ordered:
                ordered.append(dataset_id)
    return tuple(ordered)


def validate_torch_device(device: str) -> dict[str, Any]:
    import torch

    if device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA was selected but torch.cuda.is_available() is false")
    return {
        "torch_imported": True,
        "torch_version": torch.__version__,
        "selected_device": device,
        "cuda_available": bool(torch.cuda.is_available()),
    }


def main() -> int:
    args = parse_args()
    device = resolve_device(args.device)
    validate_suite_config()
    validate_test_catalogue()

    plan = build_execution_plan(
        device=device,
        profiles=args.profiles,
        levels=args.levels,
        test_ids=args.tests,
    )
    if not plan:
        raise RuntimeError("The selected configuration produced an empty execution plan")

    test_ids = list(dict.fromkeys(task.test_id for task in plan))
    dataset_ids = required_dataset_ids(test_ids)
    dataset_manifest_sha256 = validate_datasets(
        dataset_ids,
        validate_downloaded_sources=(
            bool(EXECUTION["validate_downloaded_sources"])
            and not args.skip_downloaded_source_checks
        ),
    )

    # Import every selected case module now so CI does not discover a typo halfway through
    imported_modules: list[str] = []
    for test_id in test_ids:
        spec = get_test_spec(test_id)
        module = importlib.import_module(spec.module)
        run_case = getattr(module, "run_case", None)
        if not callable(run_case):
            raise TypeError(f"{spec.module}.run_case is not callable")
        imported_modules.append(spec.module)

    summary = {
        "status": "passed",
        "device": validate_torch_device(device),
        "task_count": len(plan),
        "test_count": len(test_ids),
        "tests": test_ids,
        "profiles": list(dict.fromkeys(task.profile_id for task in plan)),
        "dataset_ids": list(dataset_ids),
        "dataset_manifest_sha256": dataset_manifest_sha256,
        "imported_modules": imported_modules,
    }
    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print("Setup validation passed")
        print(f"Device: {device}")
        print(f"Tasks: {len(plan)}")
        print(f"Tests: {len(test_ids)}")
        print(f"Profiles: {', '.join(summary['profiles'])}")
        print(f"Datasets: {', '.join(dataset_ids)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
