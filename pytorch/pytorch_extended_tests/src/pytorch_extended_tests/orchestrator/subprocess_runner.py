"""Launch one execution task in a clean Python subprocess."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping

from config.suite_config import SUBPROCESS_ENVIRONMENT
from pytorch_extended_tests.orchestrator.execution_plan import ExecutionTask
from pytorch_extended_tests.results.observation import utc_now


def write_task_file(task: ExecutionTask, results_root: Path) -> Path:
    task_directory = results_root / Path(task.status_relative_path).parent
    task_directory.mkdir(parents=True, exist_ok=True)
    path = task_directory / "task.json"
    path.write_text(
        json.dumps(task.as_dict(), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return path


def run_task_subprocess(
    task: ExecutionTask,
    *,
    results_root: Path,
    timeout_seconds: int,
) -> dict[str, Any]:
    """Run a task and return its task-status record."""

    task_file = write_task_file(task, results_root)
    command = [
        sys.executable,
        "-m",
        "pytorch_extended_tests.orchestrator.run_test_file",
        "--task-file",
        str(task_file),
        "--results-dir",
        str(results_root),
    ]
    environment = os.environ.copy()
    environment.update(SUBPROCESS_ENVIRONMENT)

    started_at = utc_now()
    task_directory = task_file.parent
    stdout_path = task_directory / "stdout.log"
    stderr_path = task_directory / "stderr.log"

    try:
        completed = subprocess.run(
            command,
            cwd=Path(__file__).resolve().parents[3],
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        stdout_path.write_text(stdout, encoding="utf-8")
        stderr_path.write_text(stderr, encoding="utf-8")
        record = _synthetic_task_record(
            task,
            status="timed_out",
            started_at=started_at,
            reason=f"Task exceeded the {timeout_seconds} second timeout",
            return_code=None,
        )
        _write_json(results_root / task.status_relative_path, record)
        print(stdout, end="")
        print(stderr, end="", file=sys.stderr)
        return record

    stdout_path.write_text(completed.stdout, encoding="utf-8")
    stderr_path.write_text(completed.stderr, encoding="utf-8")
    print(completed.stdout, end="")
    print(completed.stderr, end="", file=sys.stderr)

    status_path = results_root / task.status_relative_path
    if status_path.is_file():
        try:
            record = json.loads(status_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            record = _synthetic_task_record(
                task,
                status="failed",
                started_at=started_at,
                reason="Task status file was not valid JSON",
                return_code=completed.returncode,
            )
    else:
        record = _synthetic_task_record(
            task,
            status="failed",
            started_at=started_at,
            reason="Task process did not write its status file",
            return_code=completed.returncode,
        )

    if completed.returncode != 0 and record.get("status") == "passed":
        record["status"] = "failed"
        record["reason"] = f"Task process returned {completed.returncode} after reporting success"
    record["return_code"] = completed.returncode
    _write_json(status_path, record)
    return record


def _synthetic_task_record(
    task: ExecutionTask,
    *,
    status: str,
    started_at: str,
    reason: str,
    return_code: int | None,
) -> dict[str, Any]:
    return {
        "task_id": task.task_id,
        "test_id": task.test_id,
        "profile_id": task.profile_id,
        "device": task.device,
        "status": status,
        "started_at_utc": started_at,
        "ended_at_utc": utc_now(),
        "case_records": [],
        "reason": reason,
        "return_code": return_code,
        "observations_relative_path": task.observations_relative_path,
    }


def _write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
