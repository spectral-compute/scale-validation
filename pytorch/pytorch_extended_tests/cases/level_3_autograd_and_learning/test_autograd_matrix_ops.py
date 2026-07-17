"""Autograd cases for matrix, convolution and solve operations."""

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


def _matrix_multiplication(context: CaseContext, recorder: ObservationRecorder) -> None:
    arrays = load_prepared_npz(context, DATASET_ID, "matrix_operations.npz")
    left = as_profile_tensor(context, arrays["left"], requires_grad=True)
    weight = as_profile_tensor(context, arrays["right"], requires_grad=True)
    output = left @ weight
    loss = output.square().mean()
    _finish(
        recorder,
        forward={"output": output, "row_summary": output.mean(dim=1)},
        loss=loss,
        inputs={"left": left},
        parameters={"weight": weight},
    )


def _batched_matrix_multiplication(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "matrix_operations.npz")
    left = as_profile_tensor(context, arrays["batch_left"], requires_grad=True)
    weight = as_profile_tensor(context, arrays["batch_right"], requires_grad=True)
    output = torch.bmm(left, weight)
    loss = output.abs().mean()
    _finish(
        recorder,
        forward={"output": output, "batch_summary": output.mean(dim=(1, 2))},
        loss=loss,
        inputs={"left": left},
        parameters={"weight": weight},
    )


def _convolution(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch.nn.functional as functional

    arrays = load_prepared_npz(context, DATASET_ID, "convolutions.npz")
    value = as_profile_tensor(context, arrays["conv2d_input"], requires_grad=True)
    weight = as_profile_tensor(context, arrays["conv2d_weight"], requires_grad=True)
    bias = as_profile_tensor(context, arrays["conv2d_bias"], requires_grad=True)
    output = functional.conv2d(value, weight, bias, stride=2, padding=1)
    loss = output.square().mean()
    _finish(
        recorder,
        forward={"output": output, "channel_means": output.mean(dim=(0, 2, 3))},
        loss=loss,
        inputs={"value": value},
        parameters={"weight": weight, "bias": bias},
    )


def _linear_solve(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "linear_algebra.npz")
    right_hand_side = as_profile_tensor(
        context, arrays["well_conditioned_rhs"], requires_grad=True
    )
    matrix = as_profile_tensor(
        context, arrays["well_conditioned_matrix"], requires_grad=True
    )
    solution = torch.linalg.solve(matrix, right_hand_side)
    residual = matrix @ solution - right_hand_side
    loss = solution.square().mean() + residual.square().mean()
    _finish(
        recorder,
        forward={"solution": solution, "residual": residual},
        loss=loss,
        inputs={"right_hand_side": right_hand_side},
        parameters={"matrix": matrix},
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "matrix_multiplication": _matrix_multiplication,
    "batched_matrix_multiplication": _batched_matrix_multiplication,
    "convolution": _convolution,
    "linear_solve": _linear_solve,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one matrix-operation autograd case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
