"""Run the four small model-training demonstrations used by Level 0."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import BLOCK_TESTS, LEVEL_0_DEMOS
from cases.common import (
    as_profile_tensor,
    build_demo_summary,
    build_linear_classifier,
    load_module_state,
    load_prepared_npz,
    module_to_profile,
    run_composite_block,
    run_registered_case,
)
from cases.level_5_composite_models.test_attention_block import (
    run_example as run_attention_example,
)
from cases.level_5_composite_models.test_cnn_block import run_example as run_cnn_example
from cases.level_5_composite_models.test_mlp_block import run_example as run_mlp_example
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "model_inputs_v1"


def _record_summary(
    context: CaseContext,
    recorder: ObservationRecorder,
    *,
    model_type: str,
    optimiser_name: str,
    labels: object,
    outputs: dict[str, object],
) -> None:
    recorder.record(
        "summary",
        build_demo_summary(
            context,
            model_type=model_type,
            optimiser_name=optimiser_name,
            labels=labels,
            outputs=outputs,
        ),
    )


def _linear_classifier(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    value = as_profile_tensor(context, arrays["mlp_input"])
    labels = as_profile_tensor(context, arrays["mlp_labels"], dtype=torch.int64)
    model = module_to_profile(context, build_linear_classifier())
    load_module_state(context, model, "linear_initial_state.npz")

    def forward(current_model: object, retain_activations: bool) -> tuple[object, dict[str, object]]:
        logits, activations = current_model(value, return_activations=True)
        return logits, activations if retain_activations else {}

    outputs = run_composite_block(
        context,
        recorder,
        model_name="linear",
        model=model,
        labels=labels,
        forward=forward,
        optimiser_settings=LEVEL_0_DEMOS["linear"],
    )
    _record_summary(
        context,
        recorder,
        model_type="linear_classifier",
        optimiser_name=str(LEVEL_0_DEMOS["linear"]["optimiser"]),
        labels=labels,
        outputs=outputs,
    )


def _mlp_classifier(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    labels = as_profile_tensor(context, arrays["mlp_labels"], dtype=torch.int64)
    outputs = run_mlp_example(context, recorder)
    _record_summary(
        context,
        recorder,
        model_type="multilayer_perceptron",
        optimiser_name=str(BLOCK_TESTS["model_optimizers"]["mlp"]),
        labels=labels,
        outputs=outputs,
    )


def _cnn_classifier(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    labels = as_profile_tensor(context, arrays["cnn_labels"], dtype=torch.int64)
    outputs = run_cnn_example(context, recorder)
    _record_summary(
        context,
        recorder,
        model_type="convolutional_neural_network",
        optimiser_name=str(BLOCK_TESTS["model_optimizers"]["cnn"]),
        labels=labels,
        outputs=outputs,
    )


def _attention_classifier(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    labels = as_profile_tensor(context, arrays["attention_labels"], dtype=torch.int64)
    outputs = run_attention_example(context, recorder)
    _record_summary(
        context,
        recorder,
        model_type="residual_multi_head_attention",
        optimiser_name=str(BLOCK_TESTS["model_optimizers"]["attention"]),
        labels=labels,
        outputs=outputs,
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "linear_classifier": _linear_classifier,
    "mlp_classifier": _mlp_classifier,
    "cnn_classifier": _cnn_classifier,
    "attention_classifier": _attention_classifier,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run the quick demonstration selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
