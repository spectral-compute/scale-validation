"""Validate committed source and prepared datasets against the manifest."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Iterable, Mapping

from config.suite_config import (
    DATASET_MANIFEST_PATH,
    DATASET_PATHS,
    DATASETS_DIR,
    ROOT_SEED,
    SUITE_NAME,
    SUITE_VERSION,
)


class DatasetValidationError(RuntimeError):
    """Raised when committed dataset content does not match its manifest."""


def hash_file(path: Path, algorithm: str = "sha256") -> str:
    digest = hashlib.new(algorithm)
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_dataset_manifest(path: Path = DATASET_MANIFEST_PATH) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise DatasetValidationError(f"Dataset manifest does not exist: {path}") from exc
    except json.JSONDecodeError as exc:
        raise DatasetValidationError(f"Dataset manifest is not valid JSON: {path}") from exc

    if not isinstance(value, dict):
        raise DatasetValidationError("Dataset manifest must contain a JSON object")
    return value


def _validate_file_record(record: Mapping[str, Any], *, label: str) -> None:
    relative_path = record.get("relative_path")
    if not isinstance(relative_path, str) or not relative_path:
        raise DatasetValidationError(f"{label} has no valid relative_path")

    path = DATASETS_DIR / relative_path
    if not path.is_file():
        raise DatasetValidationError(f"Required dataset file is missing: {path}")

    expected_size = record.get("size_bytes")
    if not isinstance(expected_size, int):
        raise DatasetValidationError(
            f"{label} has no recorded size\n"
            "Run datasets/generate_datasets.py after adding the downloaded files"
        )
    actual_size = path.stat().st_size
    if actual_size != expected_size:
        raise DatasetValidationError(
            f"Dataset file size does not match the manifest: {path}\n"
            f"Expected {expected_size}, found {actual_size}"
        )

    expected_sha256 = record.get("sha256")
    if not isinstance(expected_sha256, str) or len(expected_sha256) != 64:
        raise DatasetValidationError(
            f"{label} has no recorded SHA-256 hash\n"
            "Run datasets/generate_datasets.py after adding the downloaded files"
        )
    actual_sha256 = hash_file(path)
    if actual_sha256 != expected_sha256:
        raise DatasetValidationError(
            f"Dataset file hash does not match the manifest: {path}\n"
            f"Expected {expected_sha256}, found {actual_sha256}"
        )

    expected_md5 = record.get("expected_md5")
    if isinstance(expected_md5, str):
        actual_md5 = hash_file(path, "md5")
        if actual_md5 != expected_md5:
            raise DatasetValidationError(
                f"Dataset file does not match the publisher MD5: {path}\n"
                f"Expected {expected_md5}, found {actual_md5}"
            )


def _dataset_entry(manifest: Mapping[str, Any], dataset_id: str) -> Mapping[str, Any]:
    if dataset_id in manifest.get("generated_datasets", {}):
        return manifest["generated_datasets"][dataset_id]
    if dataset_id in manifest.get("prepared_datasets", {}):
        return manifest["prepared_datasets"][dataset_id]
    raise DatasetValidationError(f"Dataset manifest has no entry for {dataset_id}")


def validate_datasets(
    required_dataset_ids: Iterable[str],
    *,
    validate_downloaded_sources: bool,
) -> str:
    """Validate required prepared data and return the manifest SHA-256."""

    manifest = load_dataset_manifest()
    if manifest.get("suite_name") != SUITE_NAME:
        raise DatasetValidationError("Dataset manifest suite_name does not match this suite")
    if manifest.get("suite_version") != SUITE_VERSION:
        raise DatasetValidationError("Dataset manifest suite_version does not match this suite")
    if manifest.get("root_seed") != ROOT_SEED:
        raise DatasetValidationError(
            "Dataset manifest root_seed does not match config/suite_config.py"
        )

    requested = tuple(dict.fromkeys(required_dataset_ids))
    unknown = set(requested) - set(DATASET_PATHS)
    if unknown:
        raise DatasetValidationError(f"Unknown required dataset IDs: {sorted(unknown)}")

    for dataset_id in requested:
        configured_path = DATASET_PATHS[dataset_id]
        if not configured_path.is_dir():
            raise DatasetValidationError(
                f"Prepared dataset directory is missing: {configured_path}\n"
                "Run datasets/generate_datasets.py and commit the generated files"
            )

        entry = _dataset_entry(manifest, dataset_id)
        files = entry.get("files")
        if not isinstance(files, list) or not files:
            raise DatasetValidationError(
                f"Dataset manifest has no prepared files for {dataset_id}\n"
                "Run datasets/generate_datasets.py and commit the updated manifest"
            )
        for index, record in enumerate(files):
            if not isinstance(record, Mapping):
                raise DatasetValidationError(f"Invalid file record for {dataset_id}")
            _validate_file_record(record, label=f"{dataset_id} file {index}")

    if validate_downloaded_sources:
        sources = manifest.get("sources")
        prepared_entries = manifest.get("prepared_datasets")
        if not isinstance(sources, Mapping):
            raise DatasetValidationError("Dataset manifest has no sources mapping")
        if not isinstance(prepared_entries, Mapping):
            raise DatasetValidationError("Dataset manifest has no prepared_datasets mapping")

        required_source_ids = {
            prepared_entries[dataset_id]["source_id"]
            for dataset_id in requested
            if dataset_id in prepared_entries
        }
        for source_id in required_source_ids:
            source = sources.get(source_id)
            if not isinstance(source, Mapping):
                raise DatasetValidationError(f"Invalid source entry: {source_id}")
            files = source.get("files")
            if not isinstance(files, list):
                raise DatasetValidationError(f"Source has no files list: {source_id}")
            for index, record in enumerate(files):
                if not isinstance(record, Mapping):
                    raise DatasetValidationError(f"Invalid source file entry: {source_id}")
                if record.get("required", True):
                    _validate_file_record(record, label=f"{source_id} source file {index}")

    return hash_file(DATASET_MANIFEST_PATH)
