"""Forward and backward cases for common neural-network layers."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import LEVEL_3_TESTS
from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

NUMERICAL_DATASET_ID = "numerical_inputs_v1"
MODEL_DATASET_ID = "model_inputs_v1"


def _finish(
    recorder: ObservationRecorder,
    *,
    module: object,
    forward: dict[str, object],
    loss: object,
    input_gradients: dict[str, object],
) -> None:
    loss.backward()
    recorder.record("forward", forward)
    recorder.record("loss", float(loss.detach().cpu().item()))
    recorder.record(
        "input_gradients",
        {name: value.grad.detach().clone() for name, value in input_gradients.items()},
    )
    recorder.record(
        "parameter_gradients",
        {
            name: parameter.grad.detach().clone()
            for name, parameter in module.named_parameters()
            if parameter.grad is not None
        },
    )


def _linear(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    inputs = load_prepared_npz(context, MODEL_DATASET_ID, "block_inputs.npz")
    state = load_prepared_npz(context, MODEL_DATASET_ID, "mlp_initial_state.npz")
    value = as_profile_tensor(context, inputs["mlp_input"], requires_grad=True)
    module = torch.nn.Linear(30, 32).to(device=context.device, dtype=context.torch_dtype())
    with torch.no_grad():
        module.weight.copy_(as_profile_tensor(context, state["layers.0.weight"]))
        module.bias.copy_(as_profile_tensor(context, state["layers.0.bias"]))
    output = module(value)
    activation = torch.relu(output)
    loss = activation.square().mean()
    _finish(
        recorder,
        module=module,
        forward={"output": output, "activation": activation},
        loss=loss,
        input_gradients={"value": value},
    )


def _conv_case(
    context: CaseContext,
    recorder: ObservationRecorder,
    *,
    dimension: int,
) -> None:
    import torch

    arrays = load_prepared_npz(context, NUMERICAL_DATASET_ID, "convolutions.npz")
    prefix = f"conv{dimension}d"
    value = as_profile_tensor(context, arrays[f"{prefix}_input"], requires_grad=True)
    weight = arrays[f"{prefix}_weight"]
    bias = arrays[f"{prefix}_bias"]
    convolution_class = getattr(torch.nn, f"Conv{dimension}d")
    module = convolution_class(
        in_channels=weight.shape[1],
        out_channels=weight.shape[0],
        kernel_size=weight.shape[2:],
        padding=1,
        bias=True,
    ).to(device=context.device, dtype=context.torch_dtype())
    with torch.no_grad():
        module.weight.copy_(as_profile_tensor(context, weight))
        module.bias.copy_(as_profile_tensor(context, bias))
    output = module(value)
    activation = torch.tanh(output)
    loss = activation.square().mean()
    _finish(
        recorder,
        module=module,
        forward={"output": output, "activation": activation},
        loss=loss,
        input_gradients={"value": value},
    )


def _conv1d(context: CaseContext, recorder: ObservationRecorder) -> None:
    _conv_case(context, recorder, dimension=1)


def _conv2d(context: CaseContext, recorder: ObservationRecorder) -> None:
    _conv_case(context, recorder, dimension=2)


def _conv3d(context: CaseContext, recorder: ObservationRecorder) -> None:
    _conv_case(context, recorder, dimension=3)


def _embedding(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    settings = LEVEL_3_TESTS["embedding"]
    module = torch.nn.Embedding(
        settings["num_embeddings"], settings["embedding_dim"]
    ).to(device=context.device, dtype=context.torch_dtype())
    with torch.no_grad():
        values = torch.linspace(
            -1.0,
            1.0,
            steps=settings["num_embeddings"] * settings["embedding_dim"],
            device=context.device,
            dtype=context.torch_dtype(),
        ).reshape_as(module.weight)
        module.weight.copy_(values)

    indices = torch.arange(
        settings["batch_size"] * settings["sequence_length"],
        device=context.device,
        dtype=torch.int64,
    ).reshape(settings["batch_size"], settings["sequence_length"])
    indices = indices.remainder(settings["num_embeddings"])
    token_weights = torch.linspace(
        0.5,
        1.5,
        steps=indices.numel(),
        device=context.device,
        dtype=context.torch_dtype(),
        requires_grad=True,
    ).reshape(*indices.shape, 1)
    token_weights.retain_grad()
    embedded = module(indices)
    output = embedded * token_weights
    pooled = output.mean(dim=1)
    loss = pooled.square().mean()
    _finish(
        recorder,
        module=module,
        forward={"embedded": embedded, "output": output, "pooled": pooled},
        loss=loss,
        input_gradients={"token_weights": token_weights},
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "linear": _linear,
    "conv1d": _conv1d,
    "conv2d": _conv2d,
    "conv3d": _conv3d,
    "embedding": _embedding,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one neural-network layer case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
