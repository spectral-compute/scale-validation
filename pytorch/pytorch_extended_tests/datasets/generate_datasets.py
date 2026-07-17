#!/usr/bin/env python3
"""Generate and preprocess all datasets used by pytorch_extended_tests."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import io
import json
import math
import re
import shutil
import struct
import sys
import tempfile
import unicodedata
import zipfile
from collections import Counter
from collections.abc import Iterable, Mapping, Sequence
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np


DATASETS_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = DATASETS_DIR.parent
MANIFEST_PATH = DATASETS_DIR / "dataset_manifest.json"
DOWNLOADED_DIR = DATASETS_DIR / "downloaded"
PREPARED_DIR = DATASETS_DIR / "prepared"

SPECIAL_TOKENS = ("[PAD]", "[UNK]", "[BOS]", "[EOS]")
TOKEN_PATTERN = re.compile(r"\w+(?:['’]\w+)*|[^\w\s]", flags=re.UNICODE)


class DatasetGenerationError(RuntimeError):
    """Raised when source data or generation configuration is invalid."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate deterministic inputs and preprocess downloaded datasets",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Replace prepared directories that already exist",
    )
    parser.add_argument(
        "--only",
        choices=("all", "generated", "breast-cancer", "fashion-mnist", "sms-spam"),
        default="all",
        help="Prepare one part of the dataset tree",
    )
    return parser.parse_args()


def load_suite_configuration() -> tuple[str, int, dict[str, Any]]:
    sys.path.insert(0, str(REPOSITORY_ROOT))
    try:
        from config.suite_config import DATASET_GENERATION, ROOT_SEED, SUITE_VERSION
    except (ImportError, AttributeError) as exc:
        raise DatasetGenerationError(
            "Could not load SUITE_VERSION, ROOT_SEED and DATASET_GENERATION "
            "from config/suite_config.py"
        ) from exc

    if not isinstance(SUITE_VERSION, str) or not SUITE_VERSION:
        raise DatasetGenerationError("SUITE_VERSION must be a non-empty string")
    if not isinstance(ROOT_SEED, int) or isinstance(ROOT_SEED, bool):
        raise DatasetGenerationError("ROOT_SEED must be an integer")
    if not isinstance(DATASET_GENERATION, dict):
        raise DatasetGenerationError("DATASET_GENERATION must be a dictionary")

    return SUITE_VERSION, ROOT_SEED, DATASET_GENERATION


def require_mapping(config: Mapping[str, Any], key: str) -> Mapping[str, Any]:
    value = config.get(key)
    if not isinstance(value, Mapping):
        raise DatasetGenerationError(f"DATASET_GENERATION[{key!r}] must be a mapping")
    return value


def require_int(config: Mapping[str, Any], key: str, minimum: int = 1) -> int:
    value = config.get(key)
    if not isinstance(value, int) or isinstance(value, bool) or value < minimum:
        raise DatasetGenerationError(f"{key!r} must be an integer >= {minimum}")
    return value


def require_float(
    config: Mapping[str, Any],
    key: str,
    minimum: float,
    maximum: float,
) -> float:
    value = config.get(key)
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise DatasetGenerationError(f"{key!r} must be numeric")
    result = float(value)
    if not minimum < result < maximum:
        raise DatasetGenerationError(f"{key!r} must be between {minimum} and {maximum}")
    return result


def require_int_sequence(
    config: Mapping[str, Any],
    key: str,
    expected_length: int | None = None,
) -> tuple[int, ...]:
    value = config.get(key)
    if not isinstance(value, Sequence) or isinstance(value, (str, bytes)):
        raise DatasetGenerationError(f"{key!r} must be a sequence of integers")
    result = tuple(value)
    if not result or any(not isinstance(item, int) or item < 1 for item in result):
        raise DatasetGenerationError(f"{key!r} must contain positive integers")
    if expected_length is not None and len(result) != expected_length:
        raise DatasetGenerationError(f"{key!r} must contain {expected_length} values")
    return result


def stable_seed(root_seed: int, *parts: str) -> int:
    digest = hashlib.sha256()
    digest.update(str(root_seed).encode("ascii"))
    for part in parts:
        digest.update(b"\0")
        digest.update(part.encode("utf-8"))
    return int.from_bytes(digest.digest()[:8], "big", signed=False)


def make_rng(root_seed: int, *parts: str) -> np.random.Generator:
    return np.random.default_rng(stable_seed(root_seed, *parts))


def hash_file(path: Path, algorithm: str) -> str:
    digest = hashlib.new(algorithm)
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    serialised = json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False)
    path.write_text(serialised + "\n", encoding="utf-8", newline="\n")


def write_deterministic_npz(path: Path, arrays: Mapping[str, np.ndarray]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, mode="w") as archive:
        for name in sorted(arrays):
            array = np.asarray(arrays[name])
            if array.dtype.hasobject:
                raise DatasetGenerationError(f"Object array {name!r} cannot be stored safely")

            buffer = io.BytesIO()
            np.lib.format.write_array(buffer, array, allow_pickle=False)
            member = zipfile.ZipInfo(f"{name}.npy", date_time=(1980, 1, 1, 0, 0, 0))
            member.compress_type = zipfile.ZIP_DEFLATED
            member.external_attr = 0o644 << 16
            archive.writestr(
                member,
                buffer.getvalue(),
                compress_type=zipfile.ZIP_DEFLATED,
                compresslevel=9,
            )


def replace_directory(source: Path, target: Path, force: bool) -> None:
    if target.exists():
        if not force:
            raise DatasetGenerationError(
                f"{target} already exists. Use --force to replace prepared data"
            )
        shutil.rmtree(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    source.replace(target)


def source_file(manifest: Mapping[str, Any], source_id: str, index: int = 0) -> Path:
    try:
        relative_path = manifest["sources"][source_id]["files"][index]["relative_path"]
    except (KeyError, IndexError, TypeError) as exc:
        raise DatasetGenerationError(f"Manifest source {source_id!r} is invalid") from exc
    return DATASETS_DIR / relative_path


def require_source(path: Path, urls: Sequence[str]) -> None:
    if path.is_file():
        return
    links = "\n".join(f"  {url}" for url in urls)
    raise DatasetGenerationError(
        f"Required source file is missing: {path}\nDownload it from:\n{links}"
    )


def verify_manifest_sources(manifest: Mapping[str, Any], selected_ids: set[str]) -> None:
    for source_id in selected_ids:
        source = manifest["sources"][source_id]
        urls = source["download_urls"]
        for file_spec in source["files"]:
            path = DATASETS_DIR / file_spec["relative_path"]
            require_source(path, urls)
            expected_md5 = file_spec.get("expected_md5")
            if expected_md5 is not None:
                actual_md5 = hash_file(path, "md5")
                if actual_md5.lower() != expected_md5.lower():
                    raise DatasetGenerationError(
                        f"MD5 mismatch for {path}\n"
                        f"Expected {expected_md5}\n"
                        f"Actual   {actual_md5}"
                    )


def stratified_split_indices(
    labels: np.ndarray,
    evaluation_fraction: float,
    rng: np.random.Generator,
) -> tuple[np.ndarray, np.ndarray]:
    train_parts: list[np.ndarray] = []
    evaluation_parts: list[np.ndarray] = []

    for label in np.unique(labels):
        indices = np.flatnonzero(labels == label)
        shuffled = rng.permutation(indices)
        evaluation_count = max(1, int(round(len(indices) * evaluation_fraction)))
        evaluation_count = min(evaluation_count, len(indices) - 1)
        evaluation_parts.append(shuffled[:evaluation_count])
        train_parts.append(shuffled[evaluation_count:])

    train = rng.permutation(np.concatenate(train_parts)).astype(np.int64)
    evaluation = rng.permutation(np.concatenate(evaluation_parts)).astype(np.int64)
    return train, evaluation


def balanced_subset_indices(
    labels: np.ndarray,
    total_count: int,
    rng: np.random.Generator,
) -> np.ndarray:
    classes = np.unique(labels)
    if total_count > len(labels):
        raise DatasetGenerationError(
            f"Requested {total_count} samples from a dataset with {len(labels)} rows"
        )

    base_count, remainder = divmod(total_count, len(classes))
    selected: list[np.ndarray] = []
    for position, label in enumerate(classes):
        class_count = base_count + int(position < remainder)
        candidates = np.flatnonzero(labels == label)
        if class_count > len(candidates):
            raise DatasetGenerationError(
                f"Not enough rows for class {label}: requested {class_count}, found {len(candidates)}"
            )
        selected.append(rng.permutation(candidates)[:class_count])

    return rng.permutation(np.concatenate(selected)).astype(np.int64)


def xavier_uniform(
    rng: np.random.Generator,
    shape: Sequence[int],
    fan_in: int,
    fan_out: int,
) -> np.ndarray:
    limit = math.sqrt(6.0 / float(fan_in + fan_out))
    return rng.uniform(-limit, limit, size=shape).astype(np.float32)


def linear_state(
    rng: np.random.Generator,
    prefix: str,
    input_features: int,
    output_features: int,
) -> dict[str, np.ndarray]:
    return {
        f"{prefix}.weight": xavier_uniform(
            rng,
            (output_features, input_features),
            input_features,
            output_features,
        ),
        f"{prefix}.bias": np.zeros(output_features, dtype=np.float32),
    }


def conv2d_state(
    rng: np.random.Generator,
    prefix: str,
    input_channels: int,
    output_channels: int,
    kernel_size: int,
) -> dict[str, np.ndarray]:
    fan_in = input_channels * kernel_size * kernel_size
    fan_out = output_channels * kernel_size * kernel_size
    return {
        f"{prefix}.weight": xavier_uniform(
            rng,
            (output_channels, input_channels, kernel_size, kernel_size),
            fan_in,
            fan_out,
        ),
        f"{prefix}.bias": np.zeros(output_channels, dtype=np.float32),
    }


def generate_numerical_inputs(
    target: Path,
    root_seed: int,
    config: Mapping[str, Any],
) -> None:
    vector_length = require_int(config, "vector_length", minimum=16)
    reduction_rows = require_int(config, "reduction_rows", minimum=3)
    reduction_columns = require_int(config, "reduction_columns", minimum=3)
    matrix_m = require_int(config, "matrix_m", minimum=3)
    matrix_k = require_int(config, "matrix_k", minimum=3)
    matrix_n = require_int(config, "matrix_n", minimum=3)
    matrix_batch_size = require_int(config, "matrix_batch_size", minimum=2)

    target.mkdir(parents=True, exist_ok=True)

    rng = make_rng(root_seed, "numerical_inputs", "elementwise")
    signs = np.where(np.arange(vector_length) % 2 == 0, 1.0, -1.0)
    elementwise = {
        "ordinary": rng.normal(0.0, 2.0, size=vector_length).astype(np.float64),
        "near_zero": (
            signs * np.logspace(-16, -2, num=vector_length, dtype=np.float64)
        ),
        "large_magnitude": (
            signs * np.logspace(2, 12, num=vector_length, dtype=np.float64)
        ),
        "mixed_sign": rng.uniform(-10.0, 10.0, size=vector_length).astype(np.float64),
        "positive": rng.uniform(1e-6, 20.0, size=vector_length).astype(np.float64),
        "unit_interval": rng.uniform(-0.999, 0.999, size=vector_length).astype(np.float64),
        "broadcast_left": rng.normal(size=(7, 1, 13)).astype(np.float64),
        "broadcast_right": rng.normal(size=(1, 11, 1)).astype(np.float64),
        "special_values": np.array(
            [0.0, -0.0, np.inf, -np.inf, np.nan, np.finfo(np.float64).tiny],
            dtype=np.float64,
        ),
    }
    write_deterministic_npz(target / "elementwise.npz", elementwise)

    rng = make_rng(root_seed, "numerical_inputs", "indexing")
    indexing = {
        "source": rng.normal(size=(7, 11, 13)).astype(np.float64),
        "row_indices": np.array([6, 0, 3, 3, 1], dtype=np.int64),
        "column_indices": np.array([10, 2, 8, 1, 1], dtype=np.int64),
        "gather_indices": rng.integers(0, 13, size=(7, 11, 5), dtype=np.int64),
        "boolean_mask": (rng.random((7, 11, 13)) > 0.7),
        "scatter_values": rng.normal(size=(7, 11, 5)).astype(np.float64),
    }
    write_deterministic_npz(target / "indexing.npz", indexing)

    rng = make_rng(root_seed, "numerical_inputs", "reductions")
    cancellation_pattern = np.array([1e8, 1.0, -1e8, 3.0, -3.0], dtype=np.float64)
    cancellation = np.resize(cancellation_pattern, reduction_rows * reduction_columns)
    cancellation = cancellation.reshape(reduction_rows, reduction_columns)
    reductions = {
        "positive": rng.uniform(
            0.0,
            10.0,
            size=(reduction_rows, reduction_columns),
        ).astype(np.float64),
        "mixed_sign": rng.normal(
            size=(reduction_rows, reduction_columns),
        ).astype(np.float64),
        "cancellation": cancellation,
        "cube": rng.normal(size=(5, 17, 23)).astype(np.float64),
        "integer_values": rng.integers(
            -100,
            101,
            size=(reduction_rows, reduction_columns),
            dtype=np.int64,
        ),
    }
    write_deterministic_npz(target / "reductions.npz", reductions)

    rng = make_rng(root_seed, "numerical_inputs", "matrix_operations")
    matrix_operations = {
        "left": rng.normal(size=(matrix_m, matrix_k)).astype(np.float64),
        "right": rng.normal(size=(matrix_k, matrix_n)).astype(np.float64),
        "vector": rng.normal(size=(matrix_k,)).astype(np.float64),
        "batch_left": rng.normal(
            size=(matrix_batch_size, matrix_m, matrix_k),
        ).astype(np.float64),
        "batch_right": rng.normal(
            size=(matrix_batch_size, matrix_k, matrix_n),
        ).astype(np.float64),
        "einsum_left": rng.normal(size=(5, 7, 11)).astype(np.float64),
        "einsum_right": rng.normal(size=(11, 13)).astype(np.float64),
    }
    write_deterministic_npz(target / "matrix_operations.npz", matrix_operations)

    rng = make_rng(root_seed, "numerical_inputs", "convolutions")
    convolutions = {
        "conv1d_input": rng.normal(size=(2, 3, 31)).astype(np.float64),
        "conv1d_weight": rng.normal(size=(4, 3, 5)).astype(np.float64),
        "conv1d_bias": rng.normal(size=(4,)).astype(np.float64),
        "conv2d_input": rng.normal(size=(2, 3, 17, 19)).astype(np.float64),
        "conv2d_weight": rng.normal(size=(5, 3, 3, 3)).astype(np.float64),
        "conv2d_bias": rng.normal(size=(5,)).astype(np.float64),
        "grouped_conv2d_input": rng.normal(size=(2, 4, 16, 18)).astype(np.float64),
        "grouped_conv2d_weight": rng.normal(size=(6, 2, 3, 3)).astype(np.float64),
        "grouped_conv2d_bias": rng.normal(size=(6,)).astype(np.float64),
        "conv3d_input": rng.normal(size=(1, 2, 9, 11, 13)).astype(np.float64),
        "conv3d_weight": rng.normal(size=(3, 2, 3, 3, 3)).astype(np.float64),
        "conv3d_bias": rng.normal(size=(3,)).astype(np.float64),
    }
    write_deterministic_npz(target / "convolutions.npz", convolutions)

    rng = make_rng(root_seed, "numerical_inputs", "linear_algebra")
    dimension = 17
    orthogonal, _ = np.linalg.qr(rng.normal(size=(dimension, dimension)))
    well_values = np.logspace(0.0, 2.0, dimension)
    ill_values = np.logspace(0.0, 10.0, dimension)
    well_conditioned = orthogonal @ np.diag(well_values) @ orthogonal.T
    ill_conditioned = orthogonal @ np.diag(ill_values) @ orthogonal.T
    spd = well_conditioned.T @ well_conditioned + np.eye(dimension)
    eigenvalues = np.concatenate((np.array([1.0, 1.0, 1.0]), np.arange(2, dimension - 1)))
    degenerate_symmetric = orthogonal @ np.diag(eigenvalues) @ orthogonal.T
    linear_algebra = {
        "well_conditioned_matrix": well_conditioned.astype(np.float64),
        "well_conditioned_rhs": rng.normal(size=(dimension, 3)).astype(np.float64),
        "ill_conditioned_matrix": ill_conditioned.astype(np.float64),
        "ill_conditioned_rhs": rng.normal(size=(dimension, 2)).astype(np.float64),
        "positive_definite_matrix": spd.astype(np.float64),
        "rectangular_matrix": rng.normal(size=(23, 11)).astype(np.float64),
        "svd_matrix": rng.normal(size=(19, 13)).astype(np.float64),
        "degenerate_symmetric_matrix": degenerate_symmetric.astype(np.float64),
    }
    write_deterministic_npz(target / "linear_algebra.npz", linear_algebra)

    rng = make_rng(root_seed, "numerical_inputs", "fft")
    fft_inputs = {
        "real_1d": rng.normal(size=(257,)).astype(np.float64),
        "real_2d": rng.normal(size=(31, 29)).astype(np.float64),
        "complex_1d": (
            rng.normal(size=(257,)) + 1j * rng.normal(size=(257,))
        ).astype(np.complex128),
        "complex_2d": (
            rng.normal(size=(17, 19)) + 1j * rng.normal(size=(17, 19))
        ).astype(np.complex128),
    }
    write_deterministic_npz(target / "fft.npz", fft_inputs)

    rng = make_rng(root_seed, "numerical_inputs", "special_functions")
    special_functions = {
        "positive": np.logspace(-6, 3, num=vector_length, dtype=np.float64),
        "signed": rng.uniform(-8.0, 8.0, size=vector_length).astype(np.float64),
        "probabilities": rng.uniform(1e-6, 1.0 - 1e-6, size=vector_length).astype(
            np.float64
        ),
        "gamma_inputs": rng.uniform(0.05, 20.0, size=vector_length).astype(np.float64),
        "softmax_matrix": rng.normal(size=(31, 17)).astype(np.float64),
    }
    write_deterministic_npz(target / "special_functions.npz", special_functions)

    write_json(
        target / "metadata.json",
        {
            "dataset_id": "numerical_inputs_v1",
            "root_seed": root_seed,
            "description": "Canonical inputs for core tensor and numerical kernel tests",
        },
    )


def generate_model_inputs(
    target: Path,
    root_seed: int,
    config: Mapping[str, Any],
    sms_config: Mapping[str, Any],
) -> None:
    batch_size = require_int(config, "batch_size", minimum=2)
    linear_input = require_int(config, "linear_input_features", minimum=2)
    linear_output = require_int(config, "linear_output_features", minimum=2)
    mlp_input = require_int(config, "mlp_input_features", minimum=2)
    mlp_hidden = require_int_sequence(config, "mlp_hidden_features")
    mlp_output = require_int(config, "mlp_output_features", minimum=2)
    cnn_channels = require_int_sequence(config, "cnn_channels", expected_length=3)
    cnn_classes = require_int(config, "cnn_classes", minimum=2)
    attention_length = require_int(config, "attention_sequence_length", minimum=2)
    embedding_size = require_int(config, "attention_embedding_size", minimum=4)
    attention_heads = require_int(config, "attention_heads", minimum=1)
    feedforward_size = require_int(config, "transformer_feedforward_size", minimum=4)
    transformer_layers = require_int(config, "transformer_layers", minimum=1)
    sms_sequence_length = require_int(sms_config, "max_sequence_length", minimum=4)
    vocabulary_size = require_int(sms_config, "max_vocabulary_size", minimum=8)

    if embedding_size % attention_heads != 0:
        raise DatasetGenerationError(
            "attention_embedding_size must be divisible by attention_heads"
        )

    target.mkdir(parents=True, exist_ok=True)
    rng = make_rng(root_seed, "model_inputs", "blocks")
    block_inputs = {
        "mlp_input": rng.normal(size=(batch_size, mlp_input)).astype(np.float32),
        "mlp_labels": rng.integers(0, mlp_output, size=batch_size, dtype=np.int64),
        "cnn_input": rng.normal(size=(batch_size, cnn_channels[0], 28, 28)).astype(
            np.float32
        ),
        "cnn_labels": rng.integers(0, cnn_classes, size=batch_size, dtype=np.int64),
        "attention_input": rng.normal(
            size=(batch_size, attention_length, embedding_size),
        ).astype(np.float32),
        "attention_padding_mask": (
            rng.random((batch_size, attention_length)) < 0.15
        ),
        "attention_labels": rng.integers(0, 2, size=batch_size, dtype=np.int64),
    }
    block_inputs["attention_padding_mask"][:, 0] = False
    write_deterministic_npz(target / "block_inputs.npz", block_inputs)

    rng = make_rng(root_seed, "model_inputs", "linear_state")
    linear_model_state = linear_state(
        rng,
        "linear",
        linear_input,
        linear_output,
    )
    write_deterministic_npz(
        target / "linear_initial_state.npz",
        linear_model_state,
    )

    rng = make_rng(root_seed, "model_inputs", "mlp_state")
    mlp_state: dict[str, np.ndarray] = {}
    layer_sizes = (mlp_input, *mlp_hidden, mlp_output)
    for index, (input_size, output_size) in enumerate(zip(layer_sizes, layer_sizes[1:])):
        mlp_state.update(linear_state(rng, f"layers.{index}", input_size, output_size))
    write_deterministic_npz(target / "mlp_initial_state.npz", mlp_state)

    rng = make_rng(root_seed, "model_inputs", "cnn_state")
    cnn_state: dict[str, np.ndarray] = {}
    cnn_state.update(conv2d_state(rng, "features.0", cnn_channels[0], cnn_channels[1], 3))
    cnn_state.update(conv2d_state(rng, "features.3", cnn_channels[1], cnn_channels[2], 3))
    flattened_features = cnn_channels[2] * 7 * 7
    cnn_state.update(linear_state(rng, "classifier.0", flattened_features, 64))
    cnn_state.update(linear_state(rng, "classifier.2", 64, cnn_classes))
    write_deterministic_npz(target / "cnn_initial_state.npz", cnn_state)

    rng = make_rng(root_seed, "model_inputs", "attention_state")
    attention_state: dict[str, np.ndarray] = {}
    attention_state.update(linear_state(rng, "q_proj", embedding_size, embedding_size))
    attention_state.update(linear_state(rng, "k_proj", embedding_size, embedding_size))
    attention_state.update(linear_state(rng, "v_proj", embedding_size, embedding_size))
    attention_state.update(linear_state(rng, "out_proj", embedding_size, embedding_size))
    attention_state["norm.weight"] = np.ones(embedding_size, dtype=np.float32)
    attention_state["norm.bias"] = np.zeros(embedding_size, dtype=np.float32)
    attention_state.update(linear_state(rng, "classifier", embedding_size, 2))
    write_deterministic_npz(target / "attention_initial_state.npz", attention_state)

    rng = make_rng(root_seed, "model_inputs", "sms_transformer_state")
    transformer_state: dict[str, np.ndarray] = {
        "token_embedding.weight": rng.normal(
            0.0,
            embedding_size ** -0.5,
            size=(vocabulary_size, embedding_size),
        ).astype(np.float32),
        "position_embedding.weight": rng.normal(
            0.0,
            embedding_size ** -0.5,
            size=(sms_sequence_length, embedding_size),
        ).astype(np.float32),
    }
    transformer_state["token_embedding.weight"][0] = 0.0

    for layer_index in range(transformer_layers):
        prefix = f"encoder.layers.{layer_index}"
        transformer_state[f"{prefix}.self_attn.in_proj_weight"] = xavier_uniform(
            rng,
            (3 * embedding_size, embedding_size),
            embedding_size,
            3 * embedding_size,
        )
        transformer_state[f"{prefix}.self_attn.in_proj_bias"] = np.zeros(
            3 * embedding_size,
            dtype=np.float32,
        )
        transformer_state.update(
            linear_state(
                rng,
                f"{prefix}.self_attn.out_proj",
                embedding_size,
                embedding_size,
            )
        )
        transformer_state.update(
            linear_state(rng, f"{prefix}.linear1", embedding_size, feedforward_size)
        )
        transformer_state.update(
            linear_state(rng, f"{prefix}.linear2", feedforward_size, embedding_size)
        )
        for norm_name in ("norm1", "norm2"):
            transformer_state[f"{prefix}.{norm_name}.weight"] = np.ones(
                embedding_size,
                dtype=np.float32,
            )
            transformer_state[f"{prefix}.{norm_name}.bias"] = np.zeros(
                embedding_size,
                dtype=np.float32,
            )

    transformer_state["final_norm.weight"] = np.ones(embedding_size, dtype=np.float32)
    transformer_state["final_norm.bias"] = np.zeros(embedding_size, dtype=np.float32)
    transformer_state.update(linear_state(rng, "classifier", embedding_size, 2))
    write_deterministic_npz(
        target / "sms_transformer_initial_state.npz",
        transformer_state,
    )

    write_json(
        target / "metadata.json",
        {
            "dataset_id": "model_inputs_v1",
            "root_seed": root_seed,
            "attention_heads": attention_heads,
            "description": "Fixed model inputs and initial states for block and workload tests",
        },
    )


def find_zip_member(archive: zipfile.ZipFile, expected_name: str) -> str:
    matches = [name for name in archive.namelist() if Path(name).name == expected_name]
    if len(matches) != 1:
        raise DatasetGenerationError(
            f"Expected one {expected_name!r} file in archive, found {len(matches)}"
        )
    return matches[0]


def prepare_breast_cancer(
    target: Path,
    archive_path: Path,
    root_seed: int,
    config: Mapping[str, Any],
) -> None:
    evaluation_fraction = require_float(config, "evaluation_fraction", 0.0, 1.0)

    with zipfile.ZipFile(archive_path) as archive:
        member = find_zip_member(archive, "wdbc.data")
        raw_text = archive.read(member).decode("utf-8")

    rows = list(csv.reader(io.StringIO(raw_text)))
    if len(rows) != 569:
        raise DatasetGenerationError(f"Expected 569 breast cancer rows, found {len(rows)}")

    features = np.empty((len(rows), 30), dtype=np.float64)
    labels = np.empty(len(rows), dtype=np.int64)
    identifiers = np.empty(len(rows), dtype=np.int64)
    label_map = {"B": 0, "M": 1}

    for index, row in enumerate(rows):
        if len(row) != 32:
            raise DatasetGenerationError(
                f"Breast cancer row {index} has {len(row)} columns instead of 32"
            )
        identifiers[index] = int(row[0])
        try:
            labels[index] = label_map[row[1]]
        except KeyError as exc:
            raise DatasetGenerationError(f"Unknown diagnosis label {row[1]!r}") from exc
        features[index] = np.asarray(row[2:], dtype=np.float64)

    rng = make_rng(root_seed, "breast_cancer_wisconsin", "split")
    train_indices, evaluation_indices = stratified_split_indices(
        labels,
        evaluation_fraction,
        rng,
    )

    training_features = features[train_indices]
    mean = training_features.mean(axis=0, dtype=np.float64)
    standard_deviation = training_features.std(axis=0, dtype=np.float64)
    if np.any(standard_deviation == 0.0):
        raise DatasetGenerationError("A breast cancer feature has zero training variance")

    standardised = ((features - mean) / standard_deviation).astype(np.float32)
    write_deterministic_npz(
        target / "train.npz",
        {
            "features": standardised[train_indices],
            "labels": labels[train_indices],
            "source_indices": train_indices,
            "source_identifiers": identifiers[train_indices],
        },
    )
    write_deterministic_npz(
        target / "evaluation.npz",
        {
            "features": standardised[evaluation_indices],
            "labels": labels[evaluation_indices],
            "source_indices": evaluation_indices,
            "source_identifiers": identifiers[evaluation_indices],
        },
    )
    write_deterministic_npz(
        target / "preprocessing.npz",
        {
            "training_mean": mean,
            "training_standard_deviation": standard_deviation,
        },
    )
    write_json(
        target / "metadata.json",
        {
            "dataset_id": "breast_cancer_wisconsin_v1",
            "root_seed": root_seed,
            "source_rows": len(rows),
            "training_rows": len(train_indices),
            "evaluation_rows": len(evaluation_indices),
            "feature_count": features.shape[1],
            "label_mapping": {"benign": 0, "malignant": 1},
            "evaluation_fraction": evaluation_fraction,
            "standardisation": "Training split mean and population standard deviation",
        },
    )


def read_idx_images(path: Path) -> np.ndarray:
    with gzip.open(path, "rb") as handle:
        header = handle.read(16)
        if len(header) != 16:
            raise DatasetGenerationError(f"Invalid IDX image header in {path}")
        magic, count, rows, columns = struct.unpack(">IIII", header)
        if magic != 2051:
            raise DatasetGenerationError(f"Unexpected IDX image magic {magic} in {path}")
        raw = handle.read()

    expected_size = count * rows * columns
    if len(raw) != expected_size:
        raise DatasetGenerationError(
            f"Expected {expected_size} image bytes in {path}, found {len(raw)}"
        )
    return np.frombuffer(raw, dtype=np.uint8).reshape(count, rows, columns).copy()


def read_idx_labels(path: Path) -> np.ndarray:
    with gzip.open(path, "rb") as handle:
        header = handle.read(8)
        if len(header) != 8:
            raise DatasetGenerationError(f"Invalid IDX label header in {path}")
        magic, count = struct.unpack(">II", header)
        if magic != 2049:
            raise DatasetGenerationError(f"Unexpected IDX label magic {magic} in {path}")
        raw = handle.read()

    if len(raw) != count:
        raise DatasetGenerationError(
            f"Expected {count} label bytes in {path}, found {len(raw)}"
        )
    return np.frombuffer(raw, dtype=np.uint8).copy()


def prepare_fashion_mnist(
    target: Path,
    source_paths: Sequence[Path],
    root_seed: int,
    config: Mapping[str, Any],
) -> None:
    training_samples = require_int(config, "training_samples", minimum=10)
    evaluation_samples = require_int(config, "evaluation_samples", minimum=10)

    train_images = read_idx_images(source_paths[0])
    train_labels = read_idx_labels(source_paths[1])
    evaluation_images = read_idx_images(source_paths[2])
    evaluation_labels = read_idx_labels(source_paths[3])

    if train_images.shape != (60000, 28, 28) or train_labels.shape != (60000,):
        raise DatasetGenerationError("Fashion-MNIST training files have unexpected shapes")
    if evaluation_images.shape != (10000, 28, 28) or evaluation_labels.shape != (10000,):
        raise DatasetGenerationError("Fashion-MNIST test files have unexpected shapes")

    training_indices = balanced_subset_indices(
        train_labels,
        training_samples,
        make_rng(root_seed, "fashion_mnist", "training_subset"),
    )
    evaluation_indices = balanced_subset_indices(
        evaluation_labels,
        evaluation_samples,
        make_rng(root_seed, "fashion_mnist", "evaluation_subset"),
    )

    prepared_training = (
        train_images[training_indices, np.newaxis, :, :].astype(np.float32) / 255.0
    )
    prepared_evaluation = (
        evaluation_images[evaluation_indices, np.newaxis, :, :].astype(np.float32) / 255.0
    )

    write_deterministic_npz(
        target / "train.npz",
        {
            "images": prepared_training,
            "labels": train_labels[training_indices].astype(np.int64),
            "source_indices": training_indices,
        },
    )
    write_deterministic_npz(
        target / "evaluation.npz",
        {
            "images": prepared_evaluation,
            "labels": evaluation_labels[evaluation_indices].astype(np.int64),
            "source_indices": evaluation_indices,
        },
    )
    write_json(
        target / "metadata.json",
        {
            "dataset_id": "fashion_mnist_v1",
            "root_seed": root_seed,
            "training_rows": len(training_indices),
            "evaluation_rows": len(evaluation_indices),
            "image_shape": [1, 28, 28],
            "classes": 10,
            "normalisation": "uint8 pixel value divided by 255",
            "augmentation": None,
        },
    )


def decode_text_file(raw: bytes) -> tuple[str, str]:
    for encoding in ("utf-8", "utf-8-sig", "latin-1"):
        try:
            return raw.decode(encoding), encoding
        except UnicodeDecodeError:
            continue
    raise DatasetGenerationError("Could not decode the SMS source file")


def tokenise_message(message: str) -> list[str]:
    normalised = unicodedata.normalize("NFKC", message).casefold()
    return TOKEN_PATTERN.findall(normalised)


def build_vocabulary(
    messages: Sequence[str],
    maximum_size: int,
    minimum_frequency: int,
) -> dict[str, int]:
    if maximum_size < len(SPECIAL_TOKENS):
        raise DatasetGenerationError("max_vocabulary_size is smaller than the special tokens")

    counts: Counter[str] = Counter()
    for message in messages:
        counts.update(tokenise_message(message))

    candidates = [
        (token, count)
        for token, count in counts.items()
        if count >= minimum_frequency and token not in SPECIAL_TOKENS
    ]
    candidates.sort(key=lambda item: (-item[1], item[0]))
    kept = candidates[: maximum_size - len(SPECIAL_TOKENS)]

    vocabulary = {token: index for index, token in enumerate(SPECIAL_TOKENS)}
    for token, _ in kept:
        vocabulary[token] = len(vocabulary)
    return vocabulary


def encode_messages(
    messages: Sequence[str],
    vocabulary: Mapping[str, int],
    maximum_length: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    input_ids = np.zeros((len(messages), maximum_length), dtype=np.int64)
    attention_mask = np.zeros((len(messages), maximum_length), dtype=np.bool_)
    lengths = np.empty(len(messages), dtype=np.int64)

    unknown_id = vocabulary["[UNK]"]
    beginning_id = vocabulary["[BOS]"]
    end_id = vocabulary["[EOS]"]

    for row_index, message in enumerate(messages):
        token_ids = [vocabulary.get(token, unknown_id) for token in tokenise_message(message)]
        token_ids = [beginning_id, *token_ids[: maximum_length - 2], end_id]
        length = len(token_ids)
        input_ids[row_index, :length] = token_ids
        attention_mask[row_index, :length] = True
        lengths[row_index] = length

    return input_ids, attention_mask, lengths


def prepare_sms_spam(
    target: Path,
    archive_path: Path,
    root_seed: int,
    config: Mapping[str, Any],
) -> None:
    evaluation_fraction = require_float(config, "evaluation_fraction", 0.0, 1.0)
    maximum_length = require_int(config, "max_sequence_length", minimum=4)
    maximum_vocabulary_size = require_int(config, "max_vocabulary_size", minimum=8)
    minimum_frequency = require_int(config, "minimum_token_frequency", minimum=1)

    with zipfile.ZipFile(archive_path) as archive:
        member = find_zip_member(archive, "SMSSpamCollection")
        text, encoding = decode_text_file(archive.read(member))

    messages: list[str] = []
    labels: list[int] = []
    label_map = {"ham": 0, "spam": 1}
    for line_number, line in enumerate(text.splitlines(), start=1):
        if not line:
            continue
        try:
            raw_label, message = line.split("\t", 1)
            label = label_map[raw_label]
        except (ValueError, KeyError) as exc:
            raise DatasetGenerationError(f"Invalid SMS row at line {line_number}") from exc
        labels.append(label)
        messages.append(message)

    label_array = np.asarray(labels, dtype=np.int64)
    if len(messages) != 5574:
        raise DatasetGenerationError(f"Expected 5574 SMS rows, found {len(messages)}")

    train_indices, evaluation_indices = stratified_split_indices(
        label_array,
        evaluation_fraction,
        make_rng(root_seed, "sms_spam", "split"),
    )
    training_messages = [messages[index] for index in train_indices]
    evaluation_messages = [messages[index] for index in evaluation_indices]
    vocabulary = build_vocabulary(
        training_messages,
        maximum_vocabulary_size,
        minimum_frequency,
    )

    train_ids, train_mask, train_lengths = encode_messages(
        training_messages,
        vocabulary,
        maximum_length,
    )
    evaluation_ids, evaluation_mask, evaluation_lengths = encode_messages(
        evaluation_messages,
        vocabulary,
        maximum_length,
    )

    write_deterministic_npz(
        target / "train.npz",
        {
            "input_ids": train_ids,
            "attention_mask": train_mask,
            "lengths": train_lengths,
            "labels": label_array[train_indices],
            "source_indices": train_indices,
        },
    )
    write_deterministic_npz(
        target / "evaluation.npz",
        {
            "input_ids": evaluation_ids,
            "attention_mask": evaluation_mask,
            "lengths": evaluation_lengths,
            "labels": label_array[evaluation_indices],
            "source_indices": evaluation_indices,
        },
    )
    write_json(target / "vocabulary.json", vocabulary)
    write_json(
        target / "metadata.json",
        {
            "dataset_id": "sms_spam_v1",
            "root_seed": root_seed,
            "source_rows": len(messages),
            "training_rows": len(train_indices),
            "evaluation_rows": len(evaluation_indices),
            "vocabulary_size": len(vocabulary),
            "configured_maximum_vocabulary_size": maximum_vocabulary_size,
            "maximum_sequence_length": maximum_length,
            "minimum_token_frequency": minimum_frequency,
            "source_encoding": encoding,
            "label_mapping": {"ham": 0, "spam": 1},
            "tokenisation": "Unicode NFKC, casefold, regex words and punctuation",
        },
    )


def collect_file_records(directory: Path) -> list[dict[str, Any]]:
    if not directory.is_dir():
        return []
    records = []
    for path in sorted(candidate for candidate in directory.rglob("*") if candidate.is_file()):
        records.append(
            {
                "relative_path": path.relative_to(DATASETS_DIR).as_posix(),
                "sha256": hash_file(path, "sha256"),
                "size_bytes": path.stat().st_size,
            }
        )
    return records


def update_manifest(
    manifest: dict[str, Any],
    suite_version: str,
    root_seed: int,
    selected_source_ids: set[str],
) -> None:
    manifest["suite_name"] = "pytorch_extended_tests"
    manifest["suite_version"] = suite_version
    manifest["root_seed"] = root_seed
    manifest["generated_at_utc"] = datetime.now(timezone.utc).isoformat()

    for source_id, source in manifest["sources"].items():
        for file_spec in source["files"]:
            path = DATASETS_DIR / file_spec["relative_path"]
            if not path.is_file():
                # Keep the recorded provenance when only generated inputs are refreshed
                # The source archives do not need to stay in the repository after Level 6 preparation
                if source_id in selected_source_ids:
                    file_spec["md5"] = None
                    file_spec["sha256"] = None
                    file_spec["size_bytes"] = None
                continue
            file_spec["md5"] = hash_file(path, "md5")
            file_spec["sha256"] = hash_file(path, "sha256")
            file_spec["size_bytes"] = path.stat().st_size

    for entry in manifest["generated_datasets"].values():
        entry["files"] = collect_file_records(DATASETS_DIR / entry["prepared_directory"])
    for entry in manifest["prepared_datasets"].values():
        entry["files"] = collect_file_records(DATASETS_DIR / entry["prepared_directory"])

    write_json(MANIFEST_PATH, manifest)


def run_in_temporary_directory(
    name: str,
    target: Path,
    force: bool,
    action: Any,
) -> None:
    PREPARED_DIR.mkdir(parents=True, exist_ok=True)
    temporary_parent = Path(tempfile.mkdtemp(prefix=f".{name}-", dir=PREPARED_DIR))
    temporary_target = temporary_parent / name
    temporary_target.mkdir()
    try:
        action(temporary_target)
        replace_directory(temporary_target, target, force)
    finally:
        shutil.rmtree(temporary_parent, ignore_errors=True)


def load_manifest() -> dict[str, Any]:
    try:
        value = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise DatasetGenerationError(f"Could not read {MANIFEST_PATH}") from exc
    if not isinstance(value, dict):
        raise DatasetGenerationError("dataset_manifest.json must contain an object")
    return value


def main() -> int:
    args = parse_args()
    suite_version, root_seed, generation_config = load_suite_configuration()
    manifest = load_manifest()

    selected_source_ids: set[str] = set()
    if args.only in ("all", "breast-cancer"):
        selected_source_ids.add("breast_cancer_wisconsin_diagnostic")
    if args.only in ("all", "fashion-mnist"):
        selected_source_ids.add("fashion_mnist")
    if args.only in ("all", "sms-spam"):
        selected_source_ids.add("sms_spam_collection")
    verify_manifest_sources(manifest, selected_source_ids)

    numerical_config = require_mapping(generation_config, "numerical_inputs")
    model_config = require_mapping(generation_config, "model_inputs")
    breast_config = require_mapping(generation_config, "breast_cancer_wisconsin")
    fashion_config = require_mapping(generation_config, "fashion_mnist")
    sms_config = require_mapping(generation_config, "sms_spam")

    if args.only in ("all", "generated"):
        run_in_temporary_directory(
            "numerical_inputs_v1",
            PREPARED_DIR / "numerical_inputs_v1",
            args.force,
            lambda target: generate_numerical_inputs(target, root_seed, numerical_config),
        )
        run_in_temporary_directory(
            "model_inputs_v1",
            PREPARED_DIR / "model_inputs_v1",
            args.force,
            lambda target: generate_model_inputs(target, root_seed, model_config, sms_config),
        )

    if args.only in ("all", "breast-cancer"):
        breast_archive = source_file(manifest, "breast_cancer_wisconsin_diagnostic")
        run_in_temporary_directory(
            "breast_cancer_wisconsin_v1",
            PREPARED_DIR / "breast_cancer_wisconsin_v1",
            args.force,
            lambda target: prepare_breast_cancer(
                target,
                breast_archive,
                root_seed,
                breast_config,
            ),
        )

    if args.only in ("all", "fashion-mnist"):
        fashion_paths = [
            source_file(manifest, "fashion_mnist", index)
            for index in range(len(manifest["sources"]["fashion_mnist"]["files"]))
        ]
        run_in_temporary_directory(
            "fashion_mnist_v1",
            PREPARED_DIR / "fashion_mnist_v1",
            args.force,
            lambda target: prepare_fashion_mnist(
                target,
                fashion_paths,
                root_seed,
                fashion_config,
            ),
        )

    if args.only in ("all", "sms-spam"):
        sms_archive = source_file(manifest, "sms_spam_collection")
        run_in_temporary_directory(
            "sms_spam_v1",
            PREPARED_DIR / "sms_spam_v1",
            args.force,
            lambda target: prepare_sms_spam(
                target,
                sms_archive,
                root_seed,
                sms_config,
            ),
        )

    update_manifest(manifest, suite_version, root_seed, selected_source_ids)
    print(f"Prepared datasets under {PREPARED_DIR}")
    print(f"Updated {MANIFEST_PATH}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except DatasetGenerationError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
