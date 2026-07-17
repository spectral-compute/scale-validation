"""Loss-function cases covering reductions and input gradients."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "model_inputs_v1"


def _record_reductions(
    recorder: ObservationRecorder,
    builders: dict[str, Callable[[], tuple[object, object]]],
) -> None:
    losses: dict[str, object] = {}
    gradients: dict[str, object] = {}
    for reduction, builder in builders.items():
        value, loss = builder()
        objective = loss.sum() if loss.ndim else loss
        objective.backward()
        losses[reduction] = loss.detach().clone()
        gradients[reduction] = value.grad.detach().clone()
    recorder.record("losses", losses)
    recorder.record("input_gradients", gradients)


def _mse(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    source = as_profile_tensor(context, arrays["mlp_input"][:, :12])
    target = source.detach() * 0.7 - 0.15

    def build(reduction: str) -> tuple[object, object]:
        value = source.detach().clone().requires_grad_(True)
        return value, functional.mse_loss(value, target, reduction=reduction)

    _record_reductions(
        recorder,
        {reduction: lambda reduction=reduction: build(reduction) for reduction in ("none", "mean", "sum")},
    )


def _cross_entropy(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    source = as_profile_tensor(context, arrays["mlp_input"][:, :5])
    labels = as_profile_tensor(context, arrays["mlp_labels"], dtype=None)

    def build(reduction: str) -> tuple[object, object]:
        value = source.detach().clone().requires_grad_(True)
        return value, functional.cross_entropy(value, labels, reduction=reduction)

    _record_reductions(
        recorder,
        {reduction: lambda reduction=reduction: build(reduction) for reduction in ("none", "mean", "sum")},
    )


def _binary_cross_entropy_with_logits(
    context: CaseContext, recorder: ObservationRecorder
) -> None:
    import torch.nn.functional as functional

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    source = as_profile_tensor(context, arrays["mlp_input"][:, 0])
    target = as_profile_tensor(context, arrays["mlp_labels"]).to(dtype=context.torch_dtype())

    def build(reduction: str) -> tuple[object, object]:
        value = source.detach().clone().requires_grad_(True)
        return value, functional.binary_cross_entropy_with_logits(value, target, reduction=reduction)

    _record_reductions(
        recorder,
        {reduction: lambda reduction=reduction: build(reduction) for reduction in ("none", "mean", "sum")},
    )


def _kl_divergence(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch
    import torch.nn.functional as functional

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    source_logits = as_profile_tensor(context, arrays["mlp_input"][:, :7])
    target = torch.softmax(source_logits.detach() * 0.8 + 0.1, dim=-1)

    def build(reduction: str) -> tuple[object, object]:
        value = source_logits.detach().clone().requires_grad_(True)
        log_probabilities = torch.log_softmax(value, dim=-1)
        return value, functional.kl_div(log_probabilities, target, reduction=reduction)

    _record_reductions(
        recorder,
        {
            reduction: lambda reduction=reduction: build(reduction)
            for reduction in ("none", "batchmean", "sum")
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "mse": _mse,
    "cross_entropy": _cross_entropy,
    "binary_cross_entropy_with_logits": _binary_cross_entropy_with_logits,
    "kl_divergence": _kl_divergence,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one loss-function case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
