"""Exercise CUDA float16 autocast, gradient scaling and overflow handling."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import LEVEL_4_TESTS
from cases.common import (
    clone_named_gradients,
    clone_named_parameters,
    run_registered_case,
)
from cases.common.mixed_precision import (
    build_mlp_batch,
    make_grad_scaler,
    parameters_changed,
    scaler_state_record,
)
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder, UnsupportedCase


def _run(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    if torch.device(context.device).type != "cuda":
        raise UnsupportedCase("FP16 autocast is only exercised on CUDA in this suite")

    model, value, labels = build_mlp_batch(context)
    settings = LEVEL_4_TESTS["amp"]
    optimizer = torch.optim.SGD(model.parameters(), lr=float(settings["learning_rate"]))
    scaler = make_grad_scaler(context)
    initial_scale = float(scaler.get_scale())
    before = clone_named_parameters(model)

    optimizer.zero_grad(set_to_none=True)
    with context.autocast():
        logits, activations = model(value, return_activations=True)
        normal_loss = torch.nn.functional.cross_entropy(logits, labels)

    overflow_injected = context.case_id == "loss_scaler_overflow"
    backward_loss = normal_loss * float("inf") if overflow_injected else normal_loss
    scaler.scale(backward_loss).backward()
    scaler.unscale_(optimizer)
    input_gradients = {"input": value.grad.detach().clone()}
    parameter_gradients = clone_named_gradients(model)

    step_requested = context.case_id in {"optimizer_step", "loss_scaler_overflow"}
    if step_requested:
        scaler.step(optimizer)
        scaler.update()
    after = clone_named_parameters(model)
    changed = parameters_changed(before, after)
    step_skipped = bool(step_requested and not changed)

    forward = {"logits": logits.detach().clone()}
    forward.update({f"activation.{name}": item.detach().clone() for name, item in activations.items()})
    recorder.record("forward", forward)
    recorder.record("loss", float(normal_loss.detach().cpu().item()))
    recorder.record("input_gradients", input_gradients)
    recorder.record("parameter_gradients", parameter_gradients)
    recorder.record(
        "scaler_state",
        scaler_state_record(
            scaler,
            initial_scale=initial_scale,
            step_requested=step_requested,
            step_skipped=step_skipped,
            overflow_injected=overflow_injected,
        ),
    )
    recorder.record("updated_parameters", after)


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "forward": _run,
    "backward": _run,
    "optimizer_step": _run,
    "loss_scaler_overflow": _run,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one float16 AMP scenario selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
