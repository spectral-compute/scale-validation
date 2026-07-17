"""Training and evaluation cases for normalisation layers."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import LEVEL_3_TESTS
from cases.common import as_profile_tensor, clone_module_state, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "model_inputs_v1"


def _finish(
    recorder: ObservationRecorder,
    *,
    module: object,
    forward: dict[str, object],
    loss: object,
    value: object,
) -> None:
    loss.backward()
    recorder.record("forward", forward)
    recorder.record("loss", float(loss.detach().cpu().item()))
    recorder.record("input_gradients", {"value": value.grad.detach().clone()})
    recorder.record(
        "parameter_gradients",
        {
            name: parameter.grad.detach().clone()
            for name, parameter in module.named_parameters()
            if parameter.grad is not None
        },
    )
    recorder.record("module_state", clone_module_state(module))


def _attention_input(context: CaseContext) -> object:
    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    return as_profile_tensor(context, arrays["attention_input"])


def _batch_norm_training(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    settings = LEVEL_3_TESTS["normalisation"]
    value = _attention_input(context).transpose(1, 2).contiguous().requires_grad_(True)
    module = torch.nn.BatchNorm1d(
        value.shape[1],
        eps=settings["epsilon"],
        momentum=settings["batch_norm_momentum"],
    ).to(device=context.device, dtype=context.torch_dtype())
    with torch.no_grad():
        module.weight.copy_(torch.linspace(0.8, 1.2, value.shape[1], device=context.device, dtype=context.torch_dtype()))
        module.bias.copy_(torch.linspace(-0.1, 0.1, value.shape[1], device=context.device, dtype=context.torch_dtype()))
    module.train()
    first = module(value)
    second = module(value * 0.75 + 0.1)
    loss = first.square().mean() + second.abs().mean()
    _finish(
        recorder,
        module=module,
        forward={"first": first, "second": second},
        loss=loss,
        value=value,
    )


def _batch_norm_evaluation(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    settings = LEVEL_3_TESTS["normalisation"]
    value = _attention_input(context).transpose(1, 2).contiguous().requires_grad_(True)
    module = torch.nn.BatchNorm1d(
        value.shape[1],
        eps=settings["epsilon"],
        momentum=settings["batch_norm_momentum"],
    ).to(device=context.device, dtype=context.torch_dtype())
    with torch.no_grad():
        module.weight.copy_(torch.linspace(0.9, 1.1, value.shape[1], device=context.device, dtype=context.torch_dtype()))
        module.bias.copy_(torch.linspace(-0.05, 0.05, value.shape[1], device=context.device, dtype=context.torch_dtype()))
        module.running_mean.copy_(torch.linspace(-0.2, 0.2, value.shape[1], device=context.device, dtype=context.torch_dtype()))
        module.running_var.copy_(torch.linspace(0.7, 1.3, value.shape[1], device=context.device, dtype=context.torch_dtype()))
    module.eval()
    output = module(value)
    loss = output.square().mean()
    _finish(
        recorder,
        module=module,
        forward={"output": output},
        loss=loss,
        value=value,
    )


def _layer_norm(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    settings = LEVEL_3_TESTS["normalisation"]
    value = _attention_input(context).requires_grad_(True)
    module = torch.nn.LayerNorm(value.shape[-1], eps=settings["epsilon"]).to(
        device=context.device, dtype=context.torch_dtype()
    )
    with torch.no_grad():
        module.weight.copy_(torch.linspace(0.85, 1.15, value.shape[-1], device=context.device, dtype=context.torch_dtype()))
        module.bias.copy_(torch.linspace(-0.08, 0.08, value.shape[-1], device=context.device, dtype=context.torch_dtype()))
    output = module(value)
    loss = output.square().mean()
    _finish(
        recorder,
        module=module,
        forward={"output": output, "feature_means": output.mean(dim=-1)},
        loss=loss,
        value=value,
    )


def _group_norm(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    settings = LEVEL_3_TESTS["normalisation"]
    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    value = as_profile_tensor(context, arrays["cnn_input"]).repeat(1, 8, 1, 1)
    value.requires_grad_(True)
    module = torch.nn.GroupNorm(
        settings["group_norm_groups"],
        value.shape[1],
        eps=settings["epsilon"],
    ).to(device=context.device, dtype=context.torch_dtype())
    with torch.no_grad():
        module.weight.copy_(torch.linspace(0.9, 1.1, value.shape[1], device=context.device, dtype=context.torch_dtype()))
        module.bias.copy_(torch.linspace(-0.05, 0.05, value.shape[1], device=context.device, dtype=context.torch_dtype()))
    output = module(value)
    loss = output.abs().mean()
    _finish(
        recorder,
        module=module,
        forward={"output": output, "channel_means": output.mean(dim=(0, 2, 3))},
        loss=loss,
        value=value,
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "batch_norm_training": _batch_norm_training,
    "batch_norm_evaluation": _batch_norm_evaluation,
    "layer_norm": _layer_norm,
    "group_norm": _group_norm,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one normalisation case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
