"""Central configuration for the pytorch_extended_tests suite.

Keep suite-wide choices here rather than spreading them through the case files.
The dataset generator imports this module as well, so it must not import PyTorch.
"""

from __future__ import annotations

import hashlib
import os
import tempfile
from pathlib import Path
from typing import Final


SUITE_NAME: Final = "pytorch_extended_tests"
SUITE_VERSION: Final = "v1"
CONFIG_VERSION: Final = "v1"
TEST_CATALOGUE_VERSION: Final = "v1"
RESULT_FORMAT_VERSION: Final = "v1"
SEED_DERIVATION_VERSION: Final = "v1"

# This is the only root seed used by the suite
# Derive named sub-seeds with derive_seed rather than adding local constants
ROOT_SEED: Final = 42

REPOSITORY_ROOT: Final = Path(__file__).resolve().parents[1]
DATASETS_DIR: Final = REPOSITORY_ROOT / "datasets"
PREPARED_DATASETS_DIR: Final = DATASETS_DIR / "prepared"
DATASET_MANIFEST_PATH: Final = DATASETS_DIR / "dataset_manifest.json"
# Keep the CI path unchanged on Linux
# Use the normal temporary directory on Windows so local runs work there too
RESULTS_DIR: Final = (
    Path(tempfile.gettempdir()) / "ci_benchmarks" / "pytorch"
    if os.name == "nt"
    else Path("/tmp/ci_benchmarks/pytorch")
)

DEFAULT_DEVICE: Final = "cuda"
DEVICE_ENVIRONMENT_VARIABLE: Final = "PYTORCH_EXTENDED_TESTS_DEVICE"
ALLOWED_DEVICES: Final = ("cpu", "cuda")

# These must be set before the child Python process starts
# The values are fixed here so every CI environment gets the same behaviour
SUBPROCESS_ENVIRONMENT: Final = {
    "PYTHONHASHSEED": str(ROOT_SEED),
    "PYTHONUNBUFFERED": "1",
    "CUBLAS_WORKSPACE_CONFIG": ":4096:8",
    "OMP_NUM_THREADS": "1",
    "MKL_NUM_THREADS": "1",
    "OPENBLAS_NUM_THREADS": "1",
    "NUMEXPR_NUM_THREADS": "1",
}


# Keep the profile values as plain Python data
# The orchestrator will translate these strings into PyTorch settings
EXECUTION_PROFILES: Final = {
    "controlled_fp64": {
        "dtype": "float64",
        "autocast_dtype": None,
        "deterministic_algorithms": True,
        "deterministic_warn_only": False,
        "cudnn_benchmark": False,
        "cudnn_deterministic": True,
        "allow_tf32": False,
        "float32_matmul_precision": "highest",
        "cpu_threads": 1,
        "interop_threads": 1,
    },
    "controlled_fp32": {
        "dtype": "float32",
        "autocast_dtype": None,
        "deterministic_algorithms": True,
        "deterministic_warn_only": False,
        "cudnn_benchmark": False,
        "cudnn_deterministic": True,
        "allow_tf32": False,
        "float32_matmul_precision": "highest",
        "cpu_threads": 1,
        "interop_threads": 1,
    },
    "controlled_fp16": {
        "dtype": "float16",
        "autocast_dtype": None,
        "deterministic_algorithms": True,
        "deterministic_warn_only": False,
        "cudnn_benchmark": False,
        "cudnn_deterministic": True,
        "allow_tf32": False,
        "float32_matmul_precision": "highest",
        "cpu_threads": 1,
        "interop_threads": 1,
    },
    "controlled_bfloat16": {
        "dtype": "bfloat16",
        "autocast_dtype": None,
        "deterministic_algorithms": True,
        "deterministic_warn_only": False,
        "cudnn_benchmark": False,
        "cudnn_deterministic": True,
        "allow_tf32": False,
        "float32_matmul_precision": "highest",
        "cpu_threads": 1,
        "interop_threads": 1,
    },
    "amp_fp16": {
        "dtype": "float32",
        "autocast_dtype": "float16",
        "deterministic_algorithms": True,
        "deterministic_warn_only": False,
        "cudnn_benchmark": False,
        "cudnn_deterministic": True,
        "allow_tf32": False,
        "float32_matmul_precision": "highest",
        "cpu_threads": 1,
        "interop_threads": 1,
    },
    "amp_bfloat16": {
        "dtype": "float32",
        "autocast_dtype": "bfloat16",
        "deterministic_algorithms": True,
        "deterministic_warn_only": False,
        "cudnn_benchmark": False,
        "cudnn_deterministic": True,
        "allow_tf32": False,
        "float32_matmul_precision": "highest",
        "cpu_threads": 1,
        "interop_threads": 1,
    },
}

DEFAULT_PROFILE_ORDER: Final = (
    "controlled_fp64",
    "controlled_fp32",
    "controlled_fp16",
    "controlled_bfloat16",
    "amp_fp16",
    "amp_bfloat16",
)

# CPU is mainly a diagnostic reference for the ordinary precision paths
# Extra CPU bfloat16 profiles can still be selected explicitly from the command line
DEFAULT_PROFILES_BY_DEVICE: Final = {
    # Start with the two profiles most people will care about first
    # The lower-precision CUDA profile is AMP FP16 rather than raw FP16 parameters
    "cpu": ("controlled_fp32",),
    "cuda": ("controlled_fp32", "amp_fp16"),
}

LEVELS: Final = (
    "level_0_smoke_workloads",
    "level_1_core_tensor",
    "level_2_numerical_kernels",
    "level_3_autograd_and_learning",
    "level_4_precision_and_execution",
    "level_5_composite_models",
    "level_6_real_workloads",
)



# All levels are implemented, but the normal CI job starts with Level 0 only
# Pass --levels explicitly once the quick demonstration results look sensible
IMPLEMENTED_LEVELS: Final = LEVELS
# DEFAULT_CI_LEVELS: Final = ("level_0_smoke_workloads",)
DEFAULT_CI_LEVELS: Final = (
    "level_0_smoke_workloads",
    "level_1_core_tensor",
    "level_2_numerical_kernels",
    "level_3_autograd_and_learning",
    "level_4_precision_and_execution",
    "level_5_composite_models",
)
# levels 0-5 only need the generated data from python .\datasets\generate_datasets.py --only generated --force

EXECUTION: Final = {
    "enabled_levels": DEFAULT_CI_LEVELS,
    "enabled_test_ids": (),
    "disabled_test_ids": (),
    "subprocess_timeout_seconds": 1_200,
    "continue_after_test_file_failure": True,
    "maximum_concurrent_test_files": 1,
    "fail_on_missing_required_output": True,
    "fail_on_unsupported_required_case": False,
    "remove_existing_results": True,
    "validate_downloaded_sources": True,
    "write_catalogue_snapshot": True,
}


# These are the fixed model shapes used by generated initial states and case code
MODEL_ARCHITECTURES: Final = {
    "linear": {
        "input_features": 30,
        "output_features": 2,
    },
    "mlp": {
        "input_features": 30,
        "hidden_features": (32, 16),
        "output_features": 2,
    },
    "cnn": {
        "channels": (1, 8, 16),
        "classifier_hidden_features": 64,
        "classes": 10,
    },
    "attention": {
        "sequence_length": 16,
        "embedding_size": 32,
        "heads": 4,
        "classes": 2,
    },
    "sms_transformer": {
        "sequence_length": 64,
        "vocabulary_size": 4_096,
        "embedding_size": 32,
        "heads": 4,
        "feedforward_size": 64,
        "layers": 2,
        "classes": 2,
        "activation": "gelu",
        "dropout": 0.0,
        "norm_first": False,
    },
}


# The generator reads this dictionary directly
# Keep its keys stable once prepared data has been committed
DATASET_GENERATION: Final = {
    "breast_cancer_wisconsin": {
        "evaluation_fraction": 0.2,
    },
    "fashion_mnist": {
        "training_samples": 4_096,
        "evaluation_samples": 1_024,
    },
    "sms_spam": {
        "evaluation_fraction": 0.2,
        "max_sequence_length": MODEL_ARCHITECTURES["sms_transformer"]["sequence_length"],
        "max_vocabulary_size": MODEL_ARCHITECTURES["sms_transformer"]["vocabulary_size"],
        "minimum_token_frequency": 1,
    },
    "numerical_inputs": {
        "vector_length": 257,
        "reduction_rows": 127,
        "reduction_columns": 61,
        "matrix_m": 127,
        "matrix_k": 61,
        "matrix_n": 89,
        "matrix_batch_size": 3,
    },
    "model_inputs": {
        "batch_size": 32,
        "linear_input_features": MODEL_ARCHITECTURES["linear"]["input_features"],
        "linear_output_features": MODEL_ARCHITECTURES["linear"]["output_features"],
        "mlp_input_features": MODEL_ARCHITECTURES["mlp"]["input_features"],
        "mlp_hidden_features": MODEL_ARCHITECTURES["mlp"]["hidden_features"],
        "mlp_output_features": MODEL_ARCHITECTURES["mlp"]["output_features"],
        "cnn_channels": MODEL_ARCHITECTURES["cnn"]["channels"],
        "cnn_classes": MODEL_ARCHITECTURES["cnn"]["classes"],
        "attention_sequence_length": MODEL_ARCHITECTURES["attention"]["sequence_length"],
        "attention_embedding_size": MODEL_ARCHITECTURES["attention"]["embedding_size"],
        "attention_heads": MODEL_ARCHITECTURES["attention"]["heads"],
        "transformer_feedforward_size": MODEL_ARCHITECTURES["sms_transformer"]["feedforward_size"],
        "transformer_layers": MODEL_ARCHITECTURES["sms_transformer"]["layers"],
    },
}

DATASET_PATHS: Final = {
    "numerical_inputs_v1": PREPARED_DATASETS_DIR / "numerical_inputs_v1",
    "model_inputs_v1": PREPARED_DATASETS_DIR / "model_inputs_v1",
    "breast_cancer_wisconsin_v1": PREPARED_DATASETS_DIR / "breast_cancer_wisconsin_v1",
    "fashion_mnist_v1": PREPARED_DATASETS_DIR / "fashion_mnist_v1",
    "sms_spam_v1": PREPARED_DATASETS_DIR / "sms_spam_v1",
}

DATALOADER: Final = {
    "num_workers": 0,
    "pin_memory": False,
    "persistent_workers": False,
    "drop_last": False,
}

LEVEL_3_TESTS: Final = {
    "embedding": {
        "num_embeddings": 23,
        "embedding_dim": 8,
        "batch_size": 4,
        "sequence_length": 7,
    },
    "normalisation": {
        "epsilon": 1e-5,
        "batch_norm_momentum": 0.1,
        "group_norm_groups": 4,
    },
    "optimizer_steps": 2,
    "sgd_cases": {
        "plain_sgd": {
            "lr": 0.01,
            "momentum": 0.0,
            "weight_decay": 0.0,
            "nesterov": False,
        },
        "momentum": {
            "lr": 0.01,
            "momentum": 0.9,
            "weight_decay": 0.0,
            "nesterov": False,
        },
        "nesterov": {
            "lr": 0.01,
            "momentum": 0.9,
            "weight_decay": 0.0,
            "nesterov": True,
        },
        "weight_decay": {
            "lr": 0.01,
            "momentum": 0.0,
            "weight_decay": 0.01,
            "nesterov": False,
        },
    },
    "adamw_cases": {
        "default_betas": {
            "lr": 0.001,
            "betas": (0.9, 0.999),
            "eps": 1e-8,
            "weight_decay": 0.0,
            "amsgrad": False,
        },
        "custom_betas": {
            "lr": 0.001,
            "betas": (0.8, 0.95),
            "eps": 1e-8,
            "weight_decay": 0.0,
            "amsgrad": False,
        },
        "weight_decay": {
            "lr": 0.001,
            "betas": (0.9, 0.999),
            "eps": 1e-8,
            "weight_decay": 0.01,
            "amsgrad": False,
        },
        "amsgrad": {
            "lr": 0.001,
            "betas": (0.9, 0.999),
            "eps": 1e-8,
            "weight_decay": 0.0,
            "amsgrad": True,
        },
    },
}

AMP_GRAD_SCALER: Final = {
    "initial_scale": 128.0,
    "growth_factor": 2.0,
    "backoff_factor": 0.5,
    "growth_interval": 2,
}

LEVEL_0_DEMOS: Final = {
    "summary_filename": "level_0_summary.csv",
    "prediction_preview_count": 8,
    "linear": {
        "optimiser": "sgd",
        "learning_rate": 0.02,
        "momentum": 0.0,
        "weight_decay": 0.0,
    },
}

BLOCK_TESTS: Final = {
    "optimisation_steps": 2,
    "checkpoint_steps": (0, 1, 2),
    "model_optimizers": {
        "mlp": "adamw",
        "cnn": "sgd",
        "attention": "adamw",
    },
    "sgd": {
        "learning_rate": 0.01,
        "momentum": 0.9,
        "weight_decay": 0.0,
    },
    "adamw": {
        "learning_rate": 0.001,
        "betas": (0.9, 0.999),
        "epsilon": 1e-8,
        "weight_decay": 0.01,
    },
}

WORKLOAD_CAPTURE: Final = {
    "early_parameter_state_steps": (0, 1, 2),
}

WORKLOADS: Final = {
    "tabular_classification": {
        "dataset_id": "breast_cancer_wisconsin_v1",
        "initial_state_file": "mlp_initial_state.npz",
        "training_steps": 20,
        "checkpoint_steps": (0, 1, 2, 5, 10, 20),
        "batch_size": 32,
        "evaluation_batch_size": 256,
        "shuffle_training_data": True,
        "optimiser": "adamw",
        "learning_rate": 0.001,
        "betas": (0.9, 0.999),
        "epsilon": 1e-8,
        "weight_decay": 0.0001,
    },
    "image_classification": {
        "dataset_id": "fashion_mnist_v1",
        "initial_state_file": "cnn_initial_state.npz",
        "training_steps": 30,
        "checkpoint_steps": (0, 1, 2, 5, 10, 20, 30),
        "batch_size": 64,
        "evaluation_batch_size": 256,
        "shuffle_training_data": True,
        "optimiser": "sgd",
        "learning_rate": 0.01,
        "momentum": 0.9,
        "weight_decay": 0.0001,
    },
    "transformer_sequence_classification": {
        "dataset_id": "sms_spam_v1",
        "initial_state_file": "sms_transformer_initial_state.npz",
        "training_steps": 30,
        "checkpoint_steps": (0, 1, 2, 5, 10, 20, 30),
        "batch_size": 32,
        "evaluation_batch_size": 128,
        "shuffle_training_data": True,
        "optimiser": "adamw",
        "learning_rate": 0.0005,
        "betas": (0.9, 0.999),
        "epsilon": 1e-8,
        "weight_decay": 0.01,
    },
}

PRECISION_MODE_CASES: Final = {
    "fp32_strict": {
        "allow_tf32": False,
        "float32_matmul_precision": "highest",
    },
    "fp32_high": {
        "allow_tf32": True,
        "float32_matmul_precision": "high",
    },
    "fp32_medium": {
        "allow_tf32": True,
        "float32_matmul_precision": "medium",
    },
}

LEVEL_4_TESTS: Final = {
    "amp": {
        "learning_rate": 0.01,
        "grad_scaler": AMP_GRAD_SCALER,
    },
    "serialisation": {
        "learning_rate": 0.001,
        "betas": (0.9, 0.999),
        "epsilon": 1e-8,
        "weight_decay": 0.01,
        "checkpoint_version": "v1",
        "checkpoint_step": 1,
    },
}

OUTPUT_CAPTURE: Final = {
    "store_tensor_payloads": True,
    "store_tensor_checksums": True,
    "store_first_step_gradients": True,
    "store_first_step_parameter_deltas": True,
    "store_optimizer_state": True,
    "store_final_parameters": True,
    "store_intermediate_activations_at_steps": (0,),
    "store_evaluation_logits_at_checkpoints": True,
    "maximum_inline_series_length": 4_096,
}


# Use a digest rather than hash() because Python deliberately randomises hash values
def derive_seed(*parts: str) -> int:
    """Derive a stable positive seed from ROOT_SEED and a set of names."""

    if not parts or any(not isinstance(part, str) or not part for part in parts):
        raise ValueError("derive_seed requires one or more non-empty string parts")

    digest = hashlib.sha256()
    digest.update(SEED_DERIVATION_VERSION.encode("ascii"))
    digest.update(b"\0")
    digest.update(str(ROOT_SEED).encode("ascii"))
    for part in parts:
        digest.update(b"\0")
        digest.update(part.encode("utf-8"))

    # Stay within the range accepted cleanly by NumPy and PyTorch seed APIs
    return int.from_bytes(digest.digest()[:8], "big") % (2**63 - 1)


def validate_suite_config() -> None:
    """Check configuration relationships which would otherwise fail much later."""

    if not isinstance(ROOT_SEED, int) or isinstance(ROOT_SEED, bool) or ROOT_SEED < 0:
        raise ValueError("ROOT_SEED must be a non-negative integer")
    if not RESULTS_DIR.is_absolute():
        raise ValueError("RESULTS_DIR must be an absolute path")
    if DEFAULT_DEVICE not in ALLOWED_DEVICES:
        raise ValueError("DEFAULT_DEVICE must be listed in ALLOWED_DEVICES")
    if set(DEFAULT_PROFILE_ORDER) != set(EXECUTION_PROFILES):
        raise ValueError("DEFAULT_PROFILE_ORDER must contain each execution profile once")
    if len(DEFAULT_PROFILE_ORDER) != len(set(DEFAULT_PROFILE_ORDER)):
        raise ValueError("DEFAULT_PROFILE_ORDER contains duplicate profiles")
    if set(DEFAULT_PROFILES_BY_DEVICE) != set(ALLOWED_DEVICES):
        raise ValueError("DEFAULT_PROFILES_BY_DEVICE must cover every allowed device")
    for device, profile_ids in DEFAULT_PROFILES_BY_DEVICE.items():
        if not profile_ids or set(profile_ids) - set(EXECUTION_PROFILES):
            raise ValueError(f"Invalid default profiles for {device}")
        expected_order = tuple(
            profile_id for profile_id in DEFAULT_PROFILE_ORDER if profile_id in profile_ids
        )
        if tuple(profile_ids) != expected_order:
            raise ValueError(f"Default profiles for {device} must use the central profile order")
    enabled_levels = tuple(EXECUTION["enabled_levels"])
    if not enabled_levels:
        raise ValueError("EXECUTION enabled_levels must not be empty")
    if set(enabled_levels) - set(LEVELS):
        raise ValueError("EXECUTION enabled_levels contains an unknown level")
    expected_enabled_order = tuple(level for level in LEVELS if level in enabled_levels)
    if enabled_levels != expected_enabled_order:
        raise ValueError("EXECUTION enabled_levels must use the central LEVELS order")

    linear = MODEL_ARCHITECTURES["linear"]
    mlp = MODEL_ARCHITECTURES["mlp"]
    if int(linear["input_features"]) != int(mlp["input_features"]):
        raise ValueError("The Level 0 linear and MLP inputs must use the same width")
    if int(linear["output_features"]) != int(mlp["output_features"]):
        raise ValueError("The Level 0 linear and MLP outputs must use the same class count")

    attention = MODEL_ARCHITECTURES["attention"]
    transformer = MODEL_ARCHITECTURES["sms_transformer"]
    if attention["embedding_size"] % attention["heads"] != 0:
        raise ValueError("Attention embedding size must be divisible by its head count")
    if transformer["embedding_size"] % transformer["heads"] != 0:
        raise ValueError("Transformer embedding size must be divisible by its head count")
    if int(transformer["sequence_length"]) < 2:
        raise ValueError("Transformer sequence length must be at least two")
    if int(transformer["vocabulary_size"]) < 8:
        raise ValueError("Transformer vocabulary size must be at least eight")
    if float(transformer["dropout"]) != 0.0:
        raise ValueError("The fixed Transformer workload must keep dropout disabled")
    if str(transformer["activation"]) not in {"relu", "gelu"}:
        raise ValueError("Transformer activation must be relu or gelu")

    level_0 = LEVEL_0_DEMOS
    if str(level_0["summary_filename"]) != "level_0_summary.csv":
        raise ValueError("Level 0 summary filename must remain level_0_summary.csv")
    if int(level_0["prediction_preview_count"]) < 1:
        raise ValueError("Level 0 prediction preview count must be positive")
    linear_demo = level_0["linear"]
    if linear_demo["optimiser"] != "sgd":
        raise ValueError("The Level 0 linear example must use SGD")
    if float(linear_demo["learning_rate"]) <= 0:
        raise ValueError("The Level 0 linear learning rate must be positive")

    if LEVEL_3_TESTS["optimizer_steps"] < 1:
        raise ValueError("Level 3 optimizer_steps must be at least one")
    if set(LEVEL_3_TESTS["sgd_cases"]) != {"plain_sgd", "momentum", "nesterov", "weight_decay"}:
        raise ValueError("Level 3 SGD cases do not match the catalogue")
    if set(LEVEL_3_TESTS["adamw_cases"]) != {"default_betas", "custom_betas", "weight_decay", "amsgrad"}:
        raise ValueError("Level 3 AdamW cases do not match the catalogue")

    if set(PRECISION_MODE_CASES) != {"fp32_strict", "fp32_high", "fp32_medium"}:
        raise ValueError("Level 4 precision-mode cases do not match the catalogue")
    valid_matmul_precisions = {"highest", "high", "medium"}
    for case_name, settings in PRECISION_MODE_CASES.items():
        if settings["float32_matmul_precision"] not in valid_matmul_precisions:
            raise ValueError(f"Invalid float32 matmul precision for {case_name}")
        if not isinstance(settings["allow_tf32"], bool):
            raise ValueError(f"allow_tf32 must be Boolean for {case_name}")

    scaler = LEVEL_4_TESTS["amp"]["grad_scaler"]
    if float(LEVEL_4_TESTS["amp"]["learning_rate"]) <= 0:
        raise ValueError("Level 4 AMP learning rate must be positive")
    if float(scaler["initial_scale"]) <= 0:
        raise ValueError("Level 4 GradScaler initial scale must be positive")
    if float(scaler["growth_factor"]) <= 1:
        raise ValueError("Level 4 GradScaler growth factor must be greater than one")
    if not 0 < float(scaler["backoff_factor"]) < 1:
        raise ValueError("Level 4 GradScaler backoff factor must be between zero and one")
    if int(scaler["growth_interval"]) < 1:
        raise ValueError("Level 4 GradScaler growth interval must be at least one")

    block_steps = int(BLOCK_TESTS["optimisation_steps"])
    block_checkpoints = tuple(int(value) for value in BLOCK_TESTS["checkpoint_steps"])
    if block_steps < 1:
        raise ValueError("Level 5 optimisation_steps must be at least one")
    if tuple(sorted(set(block_checkpoints))) != block_checkpoints:
        raise ValueError("Level 5 checkpoint_steps must be sorted and unique")
    if block_checkpoints[0] != 0 or block_checkpoints[-1] != block_steps:
        raise ValueError(
            "Level 5 checkpoint_steps must start at 0 and end at optimisation_steps"
        )
    expected_block_models = {"mlp", "cnn", "attention"}
    if set(BLOCK_TESTS["model_optimizers"]) != expected_block_models:
        raise ValueError("Level 5 model optimiser choices do not match the catalogue")
    if set(BLOCK_TESTS["model_optimizers"].values()) - {"sgd", "adamw"}:
        raise ValueError("Level 5 model optimisers must be sgd or adamw")
    if float(BLOCK_TESTS["sgd"]["learning_rate"]) <= 0:
        raise ValueError("Level 5 SGD learning rate must be positive")
    if float(BLOCK_TESTS["adamw"]["learning_rate"]) <= 0:
        raise ValueError("Level 5 AdamW learning rate must be positive")

    serialisation = LEVEL_4_TESTS["serialisation"]
    if float(serialisation["learning_rate"]) <= 0:
        raise ValueError("Level 4 serialisation learning rate must be positive")
    if int(serialisation["checkpoint_step"]) < 0:
        raise ValueError("Level 4 checkpoint step must be non-negative")
    if not str(serialisation["checkpoint_version"]):
        raise ValueError("Level 4 checkpoint version must not be empty")

    early_workload_steps = tuple(
        int(value) for value in WORKLOAD_CAPTURE["early_parameter_state_steps"]
    )
    if tuple(sorted(set(early_workload_steps))) != early_workload_steps:
        raise ValueError("Level 6 early parameter steps must be sorted and unique")
    if not early_workload_steps or early_workload_steps[0] != 0:
        raise ValueError("Level 6 early parameter steps must start at zero")

    expected_workloads = {
        "tabular_classification",
        "image_classification",
        "transformer_sequence_classification",
    }
    if set(WORKLOADS) != expected_workloads:
        raise ValueError("Level 6 workload names do not match the catalogue")

    for workload_name, workload in WORKLOADS.items():
        steps = int(workload["training_steps"])
        checkpoints = tuple(int(value) for value in workload["checkpoint_steps"])
        if steps < 1:
            raise ValueError(f"{workload_name} training_steps must be positive")
        if tuple(sorted(set(checkpoints))) != checkpoints:
            raise ValueError(f"{workload_name} checkpoint_steps must be sorted and unique")
        if checkpoints[0] != 0 or checkpoints[-1] != steps:
            raise ValueError(
                f"{workload_name} checkpoint_steps must start at 0 and end at training_steps"
            )
        if set(early_workload_steps) - set(checkpoints):
            raise ValueError(
                f"{workload_name} must include every early parameter step as a checkpoint"
            )
        if workload["dataset_id"] not in DATASET_PATHS:
            raise ValueError(f"{workload_name} refers to an unknown dataset")
        if int(workload["batch_size"]) < 1:
            raise ValueError(f"{workload_name} batch_size must be positive")
        if int(workload["evaluation_batch_size"]) < 1:
            raise ValueError(f"{workload_name} evaluation_batch_size must be positive")
        if float(workload["learning_rate"]) <= 0:
            raise ValueError(f"{workload_name} learning_rate must be positive")
        if workload["optimiser"] not in {"sgd", "adamw"}:
            raise ValueError(f"{workload_name} optimiser must be sgd or adamw")


validate_suite_config()
