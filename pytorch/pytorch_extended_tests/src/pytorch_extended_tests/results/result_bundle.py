"""Create and finalise the result directory collected by CI."""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path
from typing import Any, Iterable, Mapping

from config.suite_config import (
    RESULT_FORMAT_VERSION,
    ROOT_SEED,
    SUITE_NAME,
    SUITE_VERSION,
    TEST_CATALOGUE_VERSION,
)
from pytorch_extended_tests.results.level_0_summary import write_level_0_summary
from pytorch_extended_tests.results.observation import utc_now


class ResultBundle:
    """Own the top-level files for one suite invocation."""

    def __init__(self, results_root: Path, *, remove_existing: bool) -> None:
        self.results_root = results_root
        self.tasks_root = results_root / ".work" / "tasks"
        self.started_at_utc = utc_now()

        if remove_existing and results_root.exists():
            shutil.rmtree(results_root)
        results_root.mkdir(parents=True, exist_ok=True)
        self.tasks_root.mkdir(parents=True, exist_ok=True)
        (results_root / "artifacts").mkdir(parents=True, exist_ok=True)

    @staticmethod
    def hash_file(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    def write_initial_manifest(
        self,
        *,
        dataset_manifest_path: Path,
        device: str,
        profile_ids: Iterable[str],
        planned_task_count: int,
    ) -> None:
        manifest = {
            "suite_name": SUITE_NAME,
            "suite_version": SUITE_VERSION,
            "result_format_version": RESULT_FORMAT_VERSION,
            "test_catalogue_version": TEST_CATALOGUE_VERSION,
            "root_seed": ROOT_SEED,
            "dataset_manifest_sha256": self.hash_file(dataset_manifest_path),
            "device": device,
            "profile_ids": list(profile_ids),
            "planned_task_count": planned_task_count,
            "started_at_utc": self.started_at_utc,
            "ended_at_utc": None,
            "overall_execution_status": "running",
            "counts": {},
        }
        self._write_json(self.results_root / "run_manifest.json", manifest)

    def finalise(
        self,
        *,
        task_records: Iterable[Mapping[str, Any]],
        overall_status: str,
    ) -> None:
        records = list(task_records)
        self._consolidate_observations(records)
        write_level_0_summary(self.results_root, records)
        final_records = [self._final_task_record(record) for record in records]
        self._write_json(self.results_root / "test_status.json", {"tasks": final_records})

        manifest_path = self.results_root / "run_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["ended_at_utc"] = utc_now()
        manifest["overall_execution_status"] = overall_status
        manifest["counts"] = self._count_statuses(records)
        self._write_json(manifest_path, manifest)

        # Keep temporary files out of the artifact uploaded by CI
        shutil.rmtree(self.results_root / ".work", ignore_errors=True)

    def _consolidate_observations(self, task_records: list[Mapping[str, Any]]) -> None:
        output_path = self.results_root / "observations.jsonl"
        with output_path.open("w", encoding="utf-8", newline="\n") as output:
            for task in task_records:
                relative_path = task.get("observations_relative_path")
                if not isinstance(relative_path, str):
                    continue
                source_path = self.results_root / relative_path
                if not source_path.is_file():
                    continue
                with source_path.open("r", encoding="utf-8") as source:
                    shutil.copyfileobj(source, output)

    @staticmethod
    def _final_task_record(record: Mapping[str, Any]) -> dict[str, Any]:
        # The per-task observation files are removed after consolidation
        # Do not leave paths in the final status file which no longer exist
        final_record = dict(record)
        final_record.pop("observations_relative_path", None)
        final_record["observations_file"] = "observations.jsonl"
        return final_record

    @staticmethod
    def _count_statuses(records: list[Mapping[str, Any]]) -> dict[str, int]:
        counts: dict[str, int] = {}
        for record in records:
            status = str(record.get("status", "unknown"))
            counts[status] = counts.get(status, 0) + 1
        return counts

    @staticmethod
    def _write_json(path: Path, value: Any) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary_path = path.with_name(f".{path.name}.tmp")
        temporary_path.write_text(
            json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n",
            encoding="utf-8",
        )
        temporary_path.replace(path)
