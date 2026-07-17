"""Short deterministic optimisation runs for AdamW variants."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import LEVEL_3_TESTS
from cases.common import (
    as_profile_tensor,
    build_mlp,
    clone_named_gradients,
    clone_named_parameters,
    flatten_optimizer_state,
    load_module_state,
    load_prepared_npz,
    module_to_profile,
    run_registered_case,
)
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "model_inputs_v1"


def _run_optimizer(
    context: CaseContext,
    recorder: ObservationRecorder,
    *,
    settings: dict[str, object],
) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    value = as_profile_tensor(context, arrays["mlp_input"])
    labels = as_profile_tensor(context, arrays["mlp_labels"], dtype=torch.int64)
    model = module_to_profile(context, build_mlp())
    load_module_state(context, model, "mlp_initial_state.npz")
    optimizer = torch.optim.AdamW(model.parameters(), **settings)
    steps = int(LEVEL_3_TESTS["optimizer_steps"])

    loss_values: list[float] = []
    parameter_states: dict[str, object] = {"step_0": clone_named_parameters(model)}
    parameter_gradients: dict[str, object] = {}
    optimizer_states: dict[str, object] = {
        "step_0": flatten_optimizer_state(optimizer, model)
    }

    for step in range(steps):
        optimizer.zero_grad(set_to_none=True)
        logits = model(value)
        loss = torch.nn.functional.cross_entropy(logits, labels)
        loss_values.append(float(loss.detach().cpu().item()))
        loss.backward()
        parameter_gradients[f"step_{step}"] = clone_named_gradients(model)
        optimizer.step()
        parameter_states[f"step_{step + 1}"] = clone_named_parameters(model)
        optimizer_states[f"step_{step + 1}"] = flatten_optimizer_state(optimizer, model)

    with torch.no_grad():
        final_loss = torch.nn.functional.cross_entropy(model(value), labels)
    loss_values.append(float(final_loss.detach().cpu().item()))

    recorder.record("loss_series", loss_values)
    recorder.record("parameter_states", parameter_states)
    recorder.record("parameter_gradients", parameter_gradients)
    recorder.record("optimizer_states", optimizer_states)


def _case(context: CaseContext, recorder: ObservationRecorder) -> None:
    settings = dict(LEVEL_3_TESTS["adamw_cases"][context.case_id])
    _run_optimizer(context, recorder, settings=settings)


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    case_id: _case for case_id in LEVEL_3_TESTS["adamw_cases"]
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one AdamW variant selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
