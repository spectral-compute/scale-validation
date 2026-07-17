"""Autograd cases built from small elementwise computation graphs."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _finish(
    recorder: ObservationRecorder,
    *,
    forward: dict[str, object],
    loss: object,
    inputs: dict[str, object],
    parameters: dict[str, object],
) -> None:
    loss.backward()
    recorder.record("forward", forward)
    recorder.record("loss", float(loss.detach().cpu().item()))
    recorder.record(
        "input_gradients",
        {name: value.grad.detach().clone() for name, value in inputs.items()},
    )
    recorder.record(
        "parameter_gradients",
        {name: value.grad.detach().clone() for name, value in parameters.items()},
    )


def _scalar_chain(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "elementwise.npz")
    value = as_profile_tensor(context, arrays["positive"][:64], requires_grad=True)
    scale = torch.tensor(1.25, device=context.device, dtype=context.torch_dtype(), requires_grad=True)
    bias = torch.tensor(-0.1, device=context.device, dtype=context.torch_dtype(), requires_grad=True)
    affine = value * scale + bias
    output = torch.exp(affine).log1p()
    loss = output.square().mean()
    _finish(
        recorder,
        forward={"affine": affine, "output": output},
        loss=loss,
        inputs={"value": value},
        parameters={"scale": scale, "bias": bias},
    )


def _branching_graph(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "elementwise.npz")
    value = as_profile_tensor(context, arrays["mixed_sign"][:96], requires_grad=True)
    frequency = torch.tensor(0.75, device=context.device, dtype=context.torch_dtype(), requires_grad=True)
    offset = torch.tensor(0.2, device=context.device, dtype=context.torch_dtype(), requires_grad=True)
    sine_branch = torch.sin(value * frequency)
    cosine_branch = torch.cos(value + offset)
    output = sine_branch * cosine_branch + sine_branch
    loss = output.square().mean()
    _finish(
        recorder,
        forward={"sine_branch": sine_branch, "cosine_branch": cosine_branch, "output": output},
        loss=loss,
        inputs={"value": value},
        parameters={"frequency": frequency, "offset": offset},
    )


def _reused_tensor(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "elementwise.npz")
    value = as_profile_tensor(context, arrays["ordinary"][:80], requires_grad=True)
    scale = torch.tensor(1.1, device=context.device, dtype=context.torch_dtype(), requires_grad=True)
    shared = torch.tanh(value * scale)
    output = shared.square() + shared * shared.mean() + shared
    loss = output.abs().mean()
    _finish(
        recorder,
        forward={"shared": shared, "output": output},
        loss=loss,
        inputs={"value": value},
        parameters={"scale": scale},
    )


def _reduction_graph(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "reductions.npz")
    value = as_profile_tensor(context, arrays["mixed_sign"][:31, :29], requires_grad=True)
    scale = torch.tensor(0.9, device=context.device, dtype=context.torch_dtype(), requires_grad=True)
    offset = torch.tensor(0.15, device=context.device, dtype=context.torch_dtype(), requires_grad=True)
    transformed = value * scale + offset
    row_means = transformed.mean(dim=1)
    output = torch.log1p(row_means.square())
    loss = output.sum()
    _finish(
        recorder,
        forward={"transformed": transformed, "row_means": row_means, "output": output},
        loss=loss,
        inputs={"value": value},
        parameters={"scale": scale, "offset": offset},
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "scalar_chain": _scalar_chain,
    "branching_graph": _branching_graph,
    "reused_tensor": _reused_tensor,
    "reduction_graph": _reduction_graph,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one elementwise autograd case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
