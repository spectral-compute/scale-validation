"""Stable catalogue of test files, cases and expected outputs.

The catalogue is intentionally free of numerical tolerances. CI only records raw
outputs for now, and the later comparison harness will attach policies to these
stable test, case and output IDs.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Final

from config.suite_config import (
    DATASET_PATHS,
    DEFAULT_PROFILE_ORDER,
    EXECUTION_PROFILES,
    LEVELS,
    TEST_CATALOGUE_VERSION,
)


OUTPUT_KINDS: Final = {
    "exact_record",
    "scalar",
    "tensor",
    "tensor_map",
    "series",
    "invariant_bundle",
}
OUTPUT_IMPORTANCE: Final = {"required", "diagnostic", "informational"}

ALL_CONTROLLED_PROFILES: Final = (
    "controlled_fp64",
    "controlled_fp32",
    "controlled_fp16",
    "controlled_bfloat16",
)
FP32_FP64_PROFILES: Final = ("controlled_fp64", "controlled_fp32")
FP32_PROFILE: Final = ("controlled_fp32",)
TRAINING_PROFILES: Final = ("controlled_fp32", "amp_fp16", "amp_bfloat16")
AMP_FP16_PROFILE: Final = ("amp_fp16",)
AMP_BFLOAT16_PROFILE: Final = ("amp_bfloat16",)


@dataclass(frozen=True, slots=True)
class OutputSpec:
    """One named output produced by every successful case in a test file."""

    output_id: str
    kind: str
    importance: str
    description: str


@dataclass(frozen=True, slots=True)
class TestSpec:
    """Metadata needed to plan and validate one test module."""

    test_id: str
    level: str
    category: str
    module: str
    case_ids: tuple[str, ...]
    profile_ids: tuple[str, ...]
    dataset_ids: tuple[str, ...]
    outputs: tuple[OutputSpec, ...]
    required_capabilities: tuple[str, ...] = ()
    unsupported_is_allowed: bool = True


def output(
    output_id: str,
    kind: str,
    importance: str,
    description: str,
) -> OutputSpec:
    return OutputSpec(output_id, kind, importance, description)


STRUCTURE_AND_VALUES: Final = (
    output("structure", "exact_record", "required", "Shapes, dtypes and layout details"),
    output("values", "tensor_map", "required", "Named result tensors"),
)

FORWARD_AND_BACKWARD: Final = (
    output("forward", "tensor_map", "required", "Forward outputs and selected activations"),
    output("loss", "scalar", "required", "Scalar loss used for backward"),
    output("input_gradients", "tensor_map", "required", "Gradients with respect to inputs"),
    output("parameter_gradients", "tensor_map", "required", "Named parameter gradients"),
)

OPTIMISER_OUTPUTS: Final = (
    output("loss_series", "series", "required", "Loss at the initial and updated steps"),
    output("parameter_states", "tensor_map", "required", "Named parameters at each step"),
    output("parameter_gradients", "tensor_map", "required", "Named gradients at each step"),
    output("optimizer_states", "tensor_map", "required", "Named optimiser state tensors"),
)

BLOCK_OUTPUTS: Final = (
    output("initial_forward", "tensor_map", "required", "Initial block output and activations"),
    output("loss_series", "series", "required", "Loss through the short optimisation run"),
    output("first_gradients", "tensor_map", "required", "All gradients from the first backward pass"),
    output("parameter_states", "tensor_map", "required", "Parameters at configured checkpoints"),
    output("evaluation_outputs", "tensor_map", "required", "Fixed-batch outputs at checkpoints"),
)

LEVEL_0_OUTPUTS: Final = (
    *BLOCK_OUTPUTS,
    output(
        "summary",
        "exact_record",
        "required",
        "Small human-facing summary used to build level_0_summary.csv",
    ),
)

WORKLOAD_OUTPUTS: Final = (
    output("initial_logits", "tensor", "required", "Evaluation logits before training"),
    output("initial_loss", "scalar", "required", "Evaluation loss before training"),
    output("training_loss", "series", "required", "Training loss at every optimisation step"),
    output("training_batch_indices", "tensor_map", "required", "Exact source rows used by each training step"),
    output("checkpoint_logits", "tensor_map", "required", "Evaluation logits at configured checkpoints"),
    output("checkpoint_metrics", "tensor_map", "required", "Evaluation loss and accuracy at each checkpoint"),
    output("first_gradients", "tensor_map", "required", "All parameter gradients from the first step"),
    output("early_parameter_states", "tensor_map", "required", "Parameters from the early checkpoints"),
    output("optimizer_states", "tensor_map", "diagnostic", "Optimiser state at configured checkpoints"),
    output("final_parameters", "tensor_map", "diagnostic", "Final named model parameters"),
    output("final_predictions", "tensor", "diagnostic", "Final predicted classes"),
    output("final_metrics", "exact_record", "required", "Loss, accuracy and sample counts"),
)


TEST_CATALOGUE: Final = (
    TestSpec(
        test_id="demo.model_workloads",
        level="level_0_smoke_workloads",
        category="Quick model demonstrations",
        module="cases.level_0_smoke_workloads.test_demo_workloads",
        case_ids=(
            "linear_classifier",
            "mlp_classifier",
            "cnn_classifier",
            "attention_classifier",
        ),
        profile_ids=TRAINING_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=LEVEL_0_OUTPUTS,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="core.tensor_creation_and_dtypes",
        level="level_1_core_tensor",
        category="Tensor creation and dtypes",
        module="cases.level_1_core_tensor.test_tensor_creation_and_dtypes",
        case_ids=(
            "from_numpy",
            "zeros_ones_full",
            "scalar_construction",
            "dtype_conversion",
            "device_round_trip",
            "contiguous_and_non_contiguous",
        ),
        profile_ids=ALL_CONTROLLED_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=STRUCTURE_AND_VALUES,
    ),
    TestSpec(
        test_id="core.elementwise_arithmetic",
        level="level_1_core_tensor",
        category="Elementwise arithmetic",
        module="cases.level_1_core_tensor.test_elementwise_arithmetic",
        case_ids=(
            "add",
            "subtract",
            "multiply",
            "true_divide",
            "floor_divide",
            "remainder",
            "power",
            "minimum_and_maximum",
            "clamp",
        ),
        profile_ids=ALL_CONTROLLED_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(output("results", "tensor_map", "required", "Results for each numerical input class"),),
    ),
    TestSpec(
        test_id="core.transcendental_functions",
        level="level_1_core_tensor",
        category="Mathematical functions",
        module="cases.level_1_core_tensor.test_transcendental_functions",
        case_ids=(
            "exp_and_log",
            "sqrt_and_rsqrt",
            "trigonometric",
            "hyperbolic",
            "sigmoid_family",
        ),
        profile_ids=ALL_CONTROLLED_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(output("results", "tensor_map", "required", "Named function outputs"),),
    ),
    TestSpec(
        test_id="core.indexing_and_shape",
        level="level_1_core_tensor",
        category="Indexing and shape operations",
        module="cases.level_1_core_tensor.test_indexing_and_shape",
        case_ids=(
            "basic_slicing",
            "advanced_indexing",
            "boolean_masking",
            "gather",
            "scatter",
            "reshape_and_view",
            "transpose_and_permute",
            "concatenate_and_stack",
        ),
        profile_ids=ALL_CONTROLLED_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=STRUCTURE_AND_VALUES,
    ),
    TestSpec(
        test_id="core.type_promotion",
        level="level_1_core_tensor",
        category="Type promotion",
        module="cases.level_1_core_tensor.test_type_promotion",
        case_ids=(
            "integer_and_float",
            "float_widths",
            "scalar_and_tensor",
            "boolean_and_numeric",
            "complex_and_real",
        ),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=STRUCTURE_AND_VALUES,
    ),
    TestSpec(
        test_id="kernels.reductions_and_statistics",
        level="level_2_numerical_kernels",
        category="Reductions and statistics",
        module="cases.level_2_numerical_kernels.test_reductions_and_statistics",
        case_ids=(
            "sum_and_mean",
            "variance_and_standard_deviation",
            "minimum_and_maximum",
            "cumulative_operations",
            "vector_and_matrix_norms",
            "cancellation_heavy_sum",
        ),
        profile_ids=ALL_CONTROLLED_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(output("results", "tensor_map", "required", "Scalar and tensor reduction outputs"),),
    ),
    TestSpec(
        test_id="kernels.matrix_multiplication",
        level="level_2_numerical_kernels",
        category="Matrix operations",
        module="cases.level_2_numerical_kernels.test_matrix_multiplication",
        case_ids=(
            "matrix_vector",
            "matrix_matrix",
            "batched_matrix_matrix",
            "einsum",
            "inner_and_outer",
        ),
        profile_ids=ALL_CONTROLLED_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(output("results", "tensor_map", "required", "Matrix operation outputs"),),
    ),
    TestSpec(
        test_id="kernels.convolution",
        level="level_2_numerical_kernels",
        category="Convolution",
        module="cases.level_2_numerical_kernels.test_convolution",
        case_ids=("conv1d", "conv2d", "grouped_conv2d", "conv3d"),
        profile_ids=ALL_CONTROLLED_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(output("results", "tensor_map", "required", "Convolution outputs"),),
    ),
    TestSpec(
        test_id="kernels.pooling",
        level="level_2_numerical_kernels",
        category="Pooling",
        module="cases.level_2_numerical_kernels.test_pooling",
        case_ids=(
            "max_pool1d",
            "max_pool2d",
            "average_pool2d",
            "adaptive_average_pool2d",
        ),
        profile_ids=ALL_CONTROLLED_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(
            output("values", "tensor_map", "required", "Pooling outputs"),
            output("indices", "tensor_map", "required", "Indices returned by max pooling"),
        ),
    ),
    TestSpec(
        test_id="linalg.linear_solve",
        level="level_2_numerical_kernels",
        category="Linear algebra: solves",
        module="cases.level_2_numerical_kernels.test_linear_solve",
        case_ids=(
            "well_conditioned_solve",
            "ill_conditioned_solve",
            "matrix_inverse",
            "cholesky_solve",
        ),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(
            output("solutions", "tensor_map", "required", "Calculated solutions or inverses"),
            output("residuals", "tensor_map", "required", "Residuals against the original equations"),
        ),
    ),
    TestSpec(
        test_id="linalg.factorisations",
        level="level_2_numerical_kernels",
        category="Linear algebra: factorisations",
        module="cases.level_2_numerical_kernels.test_factorisations",
        case_ids=("qr", "svd", "cholesky"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(output("invariants", "invariant_bundle", "required", "Factors, reconstructions and residuals"),),
    ),
    TestSpec(
        test_id="linalg.eigensystems",
        level="level_2_numerical_kernels",
        category="Linear algebra: eigensystems",
        module="cases.level_2_numerical_kernels.test_eigensystems",
        case_ids=("symmetric_distinct", "symmetric_degenerate"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(output("invariants", "invariant_bundle", "required", "Eigenvalues, residuals and subspace projectors"),),
    ),
    TestSpec(
        test_id="kernels.fft",
        level="level_2_numerical_kernels",
        category="FFT and signal operations",
        module="cases.level_2_numerical_kernels.test_fft",
        case_ids=("fft_1d", "fft_2d", "real_fft", "inverse_round_trip"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(
            output("transforms", "tensor_map", "required", "Forward transform outputs"),
            output("reconstructions", "tensor_map", "required", "Inverse-transform reconstructions"),
        ),
    ),
    TestSpec(
        test_id="kernels.special_functions",
        level="level_2_numerical_kernels",
        category="Special mathematical functions",
        module="cases.level_2_numerical_kernels.test_special_functions",
        case_ids=(
            "erf_family",
            "gamma_family",
            "softmax_and_log_softmax",
            "logit_and_expit",
        ),
        profile_ids=ALL_CONTROLLED_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(output("results", "tensor_map", "required", "Named special-function outputs"),),
    ),
    TestSpec(
        test_id="autograd.elementwise",
        level="level_3_autograd_and_learning",
        category="Autograd",
        module="cases.level_3_autograd_and_learning.test_autograd_elementwise",
        case_ids=("scalar_chain", "branching_graph", "reused_tensor", "reduction_graph"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=FORWARD_AND_BACKWARD,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="autograd.matrix_operations",
        level="level_3_autograd_and_learning",
        category="Autograd",
        module="cases.level_3_autograd_and_learning.test_autograd_matrix_ops",
        case_ids=("matrix_multiplication", "batched_matrix_multiplication", "convolution", "linear_solve"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("numerical_inputs_v1",),
        outputs=FORWARD_AND_BACKWARD,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="nn.linear_and_convolution",
        level="level_3_autograd_and_learning",
        category="Neural-network layers",
        module="cases.level_3_autograd_and_learning.test_nn_linear_and_conv",
        case_ids=("linear", "conv1d", "conv2d", "conv3d", "embedding"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("numerical_inputs_v1", "model_inputs_v1"),
        outputs=FORWARD_AND_BACKWARD,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="nn.normalisation",
        level="level_3_autograd_and_learning",
        category="Normalisation",
        module="cases.level_3_autograd_and_learning.test_normalisation",
        case_ids=("batch_norm_training", "batch_norm_evaluation", "layer_norm", "group_norm"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=(
            *FORWARD_AND_BACKWARD,
            output("module_state", "tensor_map", "required", "Named parameters and persistent normalisation state"),
        ),
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="nn.attention",
        level="level_3_autograd_and_learning",
        category="Attention",
        module="cases.level_3_autograd_and_learning.test_attention",
        case_ids=("scaled_dot_product", "masked_scaled_dot_product", "multihead_attention"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=FORWARD_AND_BACKWARD,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="nn.losses",
        level="level_3_autograd_and_learning",
        category="Loss functions",
        module="cases.level_3_autograd_and_learning.test_losses",
        case_ids=("mse", "cross_entropy", "binary_cross_entropy_with_logits", "kl_divergence"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=(
            output("losses", "tensor_map", "required", "Losses for each reduction mode"),
            output("input_gradients", "tensor_map", "required", "Gradients with respect to loss inputs"),
        ),
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="optimizers.sgd",
        level="level_3_autograd_and_learning",
        category="Optimisers",
        module="cases.level_3_autograd_and_learning.test_optimizer_sgd",
        case_ids=("plain_sgd", "momentum", "nesterov", "weight_decay"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=OPTIMISER_OUTPUTS,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="optimizers.adamw",
        level="level_3_autograd_and_learning",
        category="Optimisers",
        module="cases.level_3_autograd_and_learning.test_optimizer_adamw",
        case_ids=("default_betas", "custom_betas", "weight_decay", "amsgrad"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=OPTIMISER_OUTPUTS,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="precision.fp32_modes",
        level="level_4_precision_and_execution",
        category="Backend precision modes",
        module="cases.level_4_precision_and_execution.test_fp32_precision_modes",
        case_ids=("fp32_strict", "fp32_high", "fp32_medium"),
        profile_ids=FP32_PROFILE,
        dataset_ids=("numerical_inputs_v1",),
        outputs=(
            output("matrix_results", "tensor_map", "required", "Matrix results under each precision mode"),
            output("convolution_results", "tensor_map", "required", "Convolution results under each precision mode"),
            output("applied_settings", "exact_record", "required", "Precision settings applied for the case"),
        ),
    ),
    TestSpec(
        test_id="precision.amp_fp16",
        level="level_4_precision_and_execution",
        category="Mixed precision",
        module="cases.level_4_precision_and_execution.test_amp_fp16",
        case_ids=("forward", "backward", "optimizer_step", "loss_scaler_overflow"),
        profile_ids=AMP_FP16_PROFILE,
        dataset_ids=("model_inputs_v1",),
        outputs=(
            *FORWARD_AND_BACKWARD,
            output("scaler_state", "exact_record", "required", "Gradient-scaler values and overflow decisions"),
            output("updated_parameters", "tensor_map", "required", "Parameters after the case, including an unchanged state when no step is requested"),
        ),
        required_capabilities=("amp_fp16",),
    ),
    TestSpec(
        test_id="precision.amp_bfloat16",
        level="level_4_precision_and_execution",
        category="Mixed precision",
        module="cases.level_4_precision_and_execution.test_amp_bfloat16",
        case_ids=("forward", "backward", "optimizer_step"),
        profile_ids=AMP_BFLOAT16_PROFILE,
        dataset_ids=("model_inputs_v1",),
        outputs=(
            *FORWARD_AND_BACKWARD,
            output("updated_parameters", "tensor_map", "required", "Parameters after the case, including an unchanged state when no step is requested"),
        ),
        required_capabilities=("amp_bfloat16",),
    ),
    TestSpec(
        test_id="execution.serialisation_roundtrip",
        level="level_4_precision_and_execution",
        category="Serialisation",
        module="cases.level_4_precision_and_execution.test_serialisation_roundtrip",
        case_ids=("tensor", "model_state", "optimizer_state", "complete_checkpoint"),
        profile_ids=FP32_FP64_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=(
            output("structure", "exact_record", "required", "Keys, dtypes and shapes after loading"),
            output("loaded_values", "tensor_map", "required", "Loaded tensor values"),
            output("post_load_forward", "tensor_map", "required", "Model outputs after loading"),
        ),
        required_capabilities=("serialisation",),
    ),
    TestSpec(
        test_id="blocks.mlp",
        level="level_5_composite_models",
        category="MLP models",
        module="cases.level_5_composite_models.test_mlp_block",
        case_ids=("forward_backward_and_updates",),
        profile_ids=TRAINING_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=BLOCK_OUTPUTS,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="blocks.cnn",
        level="level_5_composite_models",
        category="CNN models",
        module="cases.level_5_composite_models.test_cnn_block",
        case_ids=("forward_backward_and_updates",),
        profile_ids=TRAINING_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=BLOCK_OUTPUTS,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="blocks.attention",
        level="level_5_composite_models",
        category="Attention models",
        module="cases.level_5_composite_models.test_attention_block",
        case_ids=("forward_backward_and_updates",),
        profile_ids=TRAINING_PROFILES,
        dataset_ids=("model_inputs_v1",),
        outputs=BLOCK_OUTPUTS,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="workloads.tabular_classification",
        level="level_6_real_workloads",
        category="Tabular classification",
        module="cases.level_6_real_workloads.test_tabular_training_workload",
        case_ids=("breast_cancer_mlp",),
        profile_ids=TRAINING_PROFILES,
        dataset_ids=("breast_cancer_wisconsin_v1", "model_inputs_v1"),
        outputs=WORKLOAD_OUTPUTS,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="workloads.image_classification",
        level="level_6_real_workloads",
        category="Image classification",
        module="cases.level_6_real_workloads.test_cnn_training_workload",
        case_ids=("fashion_mnist_cnn",),
        profile_ids=TRAINING_PROFILES,
        dataset_ids=("fashion_mnist_v1", "model_inputs_v1"),
        outputs=WORKLOAD_OUTPUTS,
        required_capabilities=("autograd",),
    ),
    TestSpec(
        test_id="workloads.transformer_sequence_classification",
        level="level_6_real_workloads",
        category="Transformer sequence modelling",
        module="cases.level_6_real_workloads.test_transformer_training_workload",
        case_ids=("sms_spam_transformer",),
        profile_ids=TRAINING_PROFILES,
        dataset_ids=("sms_spam_v1", "model_inputs_v1"),
        outputs=WORKLOAD_OUTPUTS,
        required_capabilities=("autograd",),
    ),
)


def validate_test_catalogue() -> None:
    """Fail early when catalogue entries disagree with the central configuration."""

    test_ids: set[str] = set()
    modules: set[str] = set()

    for spec in TEST_CATALOGUE:
        if spec.test_id in test_ids:
            raise ValueError(f"Duplicate test ID: {spec.test_id}")
        test_ids.add(spec.test_id)

        if spec.module in modules:
            raise ValueError(f"Duplicate test module: {spec.module}")
        modules.add(spec.module)

        if spec.level not in LEVELS:
            raise ValueError(f"Unknown level for {spec.test_id}: {spec.level}")
        if not spec.module.startswith("cases."):
            raise ValueError(f"Test module must be in the cases package: {spec.module}")
        if not spec.case_ids or len(spec.case_ids) != len(set(spec.case_ids)):
            raise ValueError(f"Case IDs must be non-empty and unique for {spec.test_id}")
        if not spec.profile_ids:
            raise ValueError(f"No profiles configured for {spec.test_id}")

        unknown_profiles = set(spec.profile_ids) - set(EXECUTION_PROFILES)
        if unknown_profiles:
            raise ValueError(f"Unknown profiles for {spec.test_id}: {sorted(unknown_profiles)}")

        unknown_datasets = set(spec.dataset_ids) - set(DATASET_PATHS)
        if unknown_datasets:
            raise ValueError(f"Unknown datasets for {spec.test_id}: {sorted(unknown_datasets)}")

        output_ids: set[str] = set()
        for output_spec in spec.outputs:
            if output_spec.output_id in output_ids:
                raise ValueError(
                    f"Duplicate output ID {output_spec.output_id!r} for {spec.test_id}"
                )
            output_ids.add(output_spec.output_id)
            if output_spec.kind not in OUTPUT_KINDS:
                raise ValueError(
                    f"Unknown output kind {output_spec.kind!r} for {spec.test_id}"
                )
            if output_spec.importance not in OUTPUT_IMPORTANCE:
                raise ValueError(
                    f"Unknown output importance {output_spec.importance!r} for {spec.test_id}"
                )

    if tuple(DEFAULT_PROFILE_ORDER) != tuple(EXECUTION_PROFILES):
        raise ValueError("Execution profile dictionary order must match DEFAULT_PROFILE_ORDER")


def catalogue_as_dict() -> dict[str, object]:
    """Return a JSON-serialisable catalogue snapshot for result manifests."""

    return {
        "catalogue_version": TEST_CATALOGUE_VERSION,
        "tests": [asdict(spec) for spec in TEST_CATALOGUE],
    }


def get_test_spec(test_id: str) -> TestSpec:
    """Return one catalogue entry by its stable test ID."""

    try:
        return TESTS_BY_ID[test_id]
    except KeyError as exc:
        raise KeyError(f"Unknown test ID: {test_id}") from exc


def tests_for_level(level: str) -> tuple[TestSpec, ...]:
    """Return catalogue entries for one level in their declared order."""

    if level not in LEVELS:
        raise KeyError(f"Unknown test level: {level}")
    return tuple(spec for spec in TEST_CATALOGUE if spec.level == level)


validate_test_catalogue()

TESTS_BY_ID: Final = {spec.test_id: spec for spec in TEST_CATALOGUE}
