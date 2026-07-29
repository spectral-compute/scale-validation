"""Run a short deterministic optimisation path through the attention block."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import (
    as_profile_tensor,
    build_attention_block,
    load_module_state,
    load_prepared_npz,
    module_to_profile,
    run_composite_block,
    run_registered_case,
)
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "model_inputs_v1"


def run_example(context: CaseContext, recorder: ObservationRecorder) -> dict[str, object]:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    value = as_profile_tensor(context, arrays["attention_input"])
    padding_mask = as_profile_tensor(
        context,
        arrays["attention_padding_mask"],
        dtype=torch.bool,
    )
    labels = as_profile_tensor(context, arrays["attention_labels"], dtype=torch.int64)
    model = module_to_profile(context, build_attention_block())
    load_module_state(context, model, "attention_initial_state.npz")

    def forward(current_model: object, retain_activations: bool) -> tuple[object, dict[str, object]]:
        logits, activations = current_model(
            value,
            padding_mask,
            return_activations=True,
        )
        return logits, activations if retain_activations else {}

    return run_composite_block(
        context,
        recorder,
        model_name="attention",
        model=model,
        labels=labels,
        forward=forward,
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "forward_backward_and_updates": run_example,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run the attention composite case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
