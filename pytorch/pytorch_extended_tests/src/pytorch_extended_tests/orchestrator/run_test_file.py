"""Child-process entry point for one test module and execution profile."""

from __future__ import annotations

import argparse
import importlib
import json
import random
import shutil
import sys
import tempfile
import traceback
from pathlib import Path
from typing import Any, Mapping

import numpy as np

from config.suite_config import (
    EXECUTION,
    EXECUTION_PROFILES,
    derive_seed,
)
from config.test_catalogue import get_test_spec
from pytorch_extended_tests.case_api import CaseContext, UnsupportedCase
from pytorch_extended_tests.results.artifact_writer import CaseObservationWriter
from pytorch_extended_tests.results.observation import CaseExecutionRecord, utc_now
from pytorch_extended_tests.precision_settings import apply_float32_precision


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-file", type=Path, required=True)
    parser.add_argument("--results-dir", type=Path, required=True)
    return parser.parse_args()


def load_task(path: Path) -> dict[str, Any]:
    try:
        task = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"Could not read task file: {path}") from exc
    if not isinstance(task, dict):
        raise RuntimeError("Task file must contain a JSON object")
    return task


def configure_torch(profile_id: str, device_name: str) -> tuple[Any, Mapping[str, Any]]:
    import torch

    profile = EXECUTION_PROFILES[profile_id]
    device = torch.device(device_name)
    if device.type == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA was selected but torch.cuda.is_available() is false")

    torch.set_num_threads(int(profile["cpu_threads"]))
    torch.set_num_interop_threads(int(profile["interop_threads"]))
    torch.use_deterministic_algorithms(
        bool(profile["deterministic_algorithms"]),
        warn_only=bool(profile["deterministic_warn_only"]),
    )
    apply_float32_precision(
        allow_tf32=bool(profile["allow_tf32"]),
        matmul_precision=str(profile["float32_matmul_precision"]),
    )

    if hasattr(torch.backends, "cudnn"):
        torch.backends.cudnn.benchmark = bool(profile["cudnn_benchmark"])
        torch.backends.cudnn.deterministic = bool(profile["cudnn_deterministic"])

    return device, profile


def unsupported_profile_reason(profile_id: str, device: Any) -> str | None:
    import torch

    profile = EXECUTION_PROFILES[profile_id]
    if profile_id == "controlled_fp16" and device.type != "cuda":
        return "The raw FP16 profile is only exercised on CUDA in this suite"
    if profile_id == "amp_fp16" and device.type != "cuda":
        return "FP16 autocast is only exercised on CUDA in this suite"

    autocast_dtype = profile.get("autocast_dtype")
    if autocast_dtype is not None:
        autocast_available = torch.amp.autocast_mode.is_autocast_available(device.type)
        if not autocast_available:
            return f"Autocast is not available for the selected {device.type} backend"

    if profile_id in {"controlled_bfloat16", "amp_bfloat16"} and device.type == "cuda":
        if not torch.cuda.is_bf16_supported():
            return "The selected CUDA device does not support bfloat16"
    return None


def seed_everything(seed: int) -> None:
    import torch

    random.seed(seed)
    np.random.seed(seed % (2**32))
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def _case_record(
    *,
    test_id: str,
    case_id: str,
    profile_id: str,
    status: str,
    seed: int,
    started_at: str,
    writer: CaseObservationWriter,
    reason: str | None = None,
    traceback_text: str | None = None,
) -> CaseExecutionRecord:
    return CaseExecutionRecord(
        test_id=test_id,
        case_id=case_id,
        profile_id=profile_id,
        status=status,
        seed=seed,
        started_at_utc=started_at,
        ended_at_utc=utc_now(),
        produced_output_ids=writer.produced_output_ids,
        missing_required_output_ids=writer.missing_required_output_ids(),
        reason=reason,
        traceback=traceback_text,
    )


def run_cases(task: Mapping[str, Any], results_root: Path) -> tuple[str, list[dict[str, Any]], str | None]:
    test_id = str(task["test_id"])
    profile_id = str(task["profile_id"])
    device_name = str(task["device"])
    test_spec = get_test_spec(test_id)
    observations_path = results_root / str(task["observations_relative_path"])
    observations_path.parent.mkdir(parents=True, exist_ok=True)
    observations_path.unlink(missing_ok=True)

    device, profile = configure_torch(profile_id, device_name)
    profile_reason = unsupported_profile_reason(profile_id, device)

    if profile_reason is not None:
        records: list[dict[str, Any]] = []
        for case_id_value in task["case_ids"]:
            case_id = str(case_id_value)
            started_at = utc_now()
            seed = derive_seed(test_id, profile_id, case_id, "case")
            writer = CaseObservationWriter(
                results_root=results_root,
                observations_path=observations_path,
                test_spec=test_spec,
                case_id=case_id,
                profile_id=profile_id,
                seed=seed,
            )
            writer.record_skipped(profile_reason)
            records.append(
                _case_record(
                    test_id=test_id,
                    case_id=case_id,
                    profile_id=profile_id,
                    status="skipped_unsupported",
                    seed=seed,
                    started_at=started_at,
                    writer=writer,
                    reason=profile_reason,
                ).as_dict()
            )
        return "skipped_unsupported", records, profile_reason

    seed_everything(derive_seed(test_id, profile_id, "module_import"))
    try:
        module = importlib.import_module(test_spec.module)
        run_case = getattr(module, "run_case")
        if not callable(run_case):
            raise TypeError(f"{test_spec.module}.run_case is not callable")
    except Exception:
        error_text = traceback.format_exc()
        print(error_text, file=sys.stderr)
        records = []
        for case_id in task["case_ids"]:
            seed = derive_seed(test_id, profile_id, str(case_id), "case")
            writer = CaseObservationWriter(
                results_root=results_root,
                observations_path=observations_path,
                test_spec=test_spec,
                case_id=str(case_id),
                profile_id=profile_id,
                seed=seed,
            )
            writer.record_failure("Test module could not be imported")
            records.append(
                _case_record(
                    test_id=test_id,
                    case_id=str(case_id),
                    profile_id=profile_id,
                    status="failed",
                    seed=seed,
                    started_at=utc_now(),
                    writer=writer,
                    reason="Test module could not be imported",
                    traceback_text=error_text,
                ).as_dict()
            )
        return "failed", records, "Test module could not be imported"

    records = []
    for case_id_value in task["case_ids"]:
        case_id = str(case_id_value)
        started_at = utc_now()
        seed = derive_seed(test_id, profile_id, case_id, "case")
        writer = CaseObservationWriter(
            results_root=results_root,
            observations_path=observations_path,
            test_spec=test_spec,
            case_id=case_id,
            profile_id=profile_id,
            seed=seed,
        )

        seed_everything(seed)
        temporary_parent = observations_path.parent / "temporary"
        temporary_parent.mkdir(parents=True, exist_ok=True)
        temporary_directory = Path(
            tempfile.mkdtemp(prefix=f"{case_id.replace('.', '_')}-", dir=temporary_parent)
        )
        context = CaseContext(
            test_id=test_id,
            case_id=case_id,
            profile_id=profile_id,
            device=str(device),
            dtype_name=str(profile["dtype"]),
            autocast_dtype_name=profile["autocast_dtype"],
            seed=seed,
            temporary_directory=temporary_directory,
        )

        try:
            run_case(context, writer)
            missing_required = writer.missing_required_output_ids()
            if missing_required:
                reason = "Case completed without all required outputs"
                writer.record_failure(reason)
                status = "failed" if EXECUTION["fail_on_missing_required_output"] else "passed"
                records.append(
                    _case_record(
                        test_id=test_id,
                        case_id=case_id,
                        profile_id=profile_id,
                        status=status,
                        seed=seed,
                        started_at=started_at,
                        writer=writer,
                        reason=reason,
                    ).as_dict()
                )
            else:
                # Record any missing diagnostic outputs without failing the case
                writer.record_failure("Case did not produce this declared diagnostic output")
                records.append(
                    _case_record(
                        test_id=test_id,
                        case_id=case_id,
                        profile_id=profile_id,
                        status="passed",
                        seed=seed,
                        started_at=started_at,
                        writer=writer,
                    ).as_dict()
                )
        except UnsupportedCase as exc:
            reason = str(exc) or "Case is not supported by this backend"
            writer.record_skipped(reason)
            records.append(
                _case_record(
                    test_id=test_id,
                    case_id=case_id,
                    profile_id=profile_id,
                    status="skipped_unsupported",
                    seed=seed,
                    started_at=started_at,
                    writer=writer,
                    reason=reason,
                ).as_dict()
            )
        except Exception as exc:
            error_text = traceback.format_exc()
            reason = f"{type(exc).__name__}: {exc}"
            writer.record_failure(reason)
            records.append(
                _case_record(
                    test_id=test_id,
                    case_id=case_id,
                    profile_id=profile_id,
                    status="failed",
                    seed=seed,
                    started_at=started_at,
                    writer=writer,
                    reason=reason,
                    traceback_text=error_text,
                ).as_dict()
            )
            print(error_text, file=sys.stderr)
        finally:
            shutil.rmtree(temporary_directory, ignore_errors=True)

    statuses = {record["status"] for record in records}
    if "failed" in statuses:
        return "failed", records, None
    if statuses == {"skipped_unsupported"}:
        return "skipped_unsupported", records, profile_reason
    return "passed", records, None


def main() -> int:
    args = parse_args()
    task = load_task(args.task_file)
    started_at = utc_now()
    status_path = args.results_dir / str(task["status_relative_path"])

    try:
        task_status, case_records, reason = run_cases(task, args.results_dir)
    except Exception as exc:
        error_text = traceback.format_exc()
        print(error_text, file=sys.stderr)
        task_status = "failed"
        case_records = []
        reason = f"{type(exc).__name__}: {exc}"

    record = {
        "task_id": task["task_id"],
        "test_id": task["test_id"],
        "profile_id": task["profile_id"],
        "device": task["device"],
        "status": task_status,
        "started_at_utc": started_at,
        "ended_at_utc": utc_now(),
        "case_records": case_records,
        "reason": reason,
        "observations_relative_path": task["observations_relative_path"],
    }
    status_path.parent.mkdir(parents=True, exist_ok=True)
    status_path.write_text(
        json.dumps(record, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    return 0 if task_status in {"passed", "skipped_unsupported"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
