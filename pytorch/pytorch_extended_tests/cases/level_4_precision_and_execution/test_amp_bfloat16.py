"""Exercise bfloat16 autocast for forward, backward and optimiser updates."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import LEVEL_4_TESTS
from cases.common import clone_named_gradients, clone_named_parameters, run_registered_case
from cases.common.mixed_precision import build_mlp_batch
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder


def _run(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    model, value, labels = build_mlp_batch(context)
    settings = LEVEL_4_TESTS["amp"]
    optimizer = torch.optim.SGD(model.parameters(), lr=float(settings["learning_rate"]))
    optimizer.zero_grad(set_to_none=True)

    with context.autocast():
        logits, activations = model(value, return_activations=True)
        loss = torch.nn.functional.cross_entropy(logits, labels)
    loss.backward()

    input_gradients = {"input": value.grad.detach().clone()}
    parameter_gradients = clone_named_gradients(model)
    if context.case_id == "optimizer_step":
        optimizer.step()
    updated_parameters = clone_named_parameters(model)

    forward = {"logits": logits.detach().clone()}
    forward.update({f"activation.{name}": item.detach().clone() for name, item in activations.items()})
    recorder.record("forward", forward)
    recorder.record("loss", float(loss.detach().cpu().item()))
    recorder.record("input_gradients", input_gradients)
    recorder.record("parameter_gradients", parameter_gradients)
    recorder.record("updated_parameters", updated_parameters)


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "forward": _run,
    "backward": _run,
    "optimizer_step": _run,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one bfloat16 AMP scenario selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
