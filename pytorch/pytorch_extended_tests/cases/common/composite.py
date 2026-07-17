"""Shared execution loop for the Level 0 and Level 5 composite models."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from typing import Any

from config.suite_config import BLOCK_TESTS
from cases.common.learning import clone_named_gradients, clone_named_parameters
from cases.common.mixed_precision import make_grad_scaler
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

ForwardFunction = Callable[[Any, bool], tuple[Any, Mapping[str, Any]]]


def _build_optimizer(
    model_name: str,
    model: Any,
    optimiser_settings: Mapping[str, Any] | None,
) -> Any:
    import torch

    if optimiser_settings is None:
        optimiser_name = str(BLOCK_TESTS["model_optimizers"][model_name])
        settings = BLOCK_TESTS[optimiser_name]
    else:
        optimiser_name = str(optimiser_settings["optimiser"])
        settings = optimiser_settings

    if optimiser_name == "sgd":
        return torch.optim.SGD(
            model.parameters(),
            lr=float(settings["learning_rate"]),
            momentum=float(settings.get("momentum", 0.0)),
            weight_decay=float(settings.get("weight_decay", 0.0)),
        )
    if optimiser_name == "adamw":
        return torch.optim.AdamW(
            model.parameters(),
            lr=float(settings["learning_rate"]),
            betas=tuple(float(value) for value in settings["betas"]),
            eps=float(settings["epsilon"]),
            weight_decay=float(settings.get("weight_decay", 0.0)),
        )
    raise ValueError(f"Unknown composite-model optimiser: {optimiser_name}")


def _evaluation(
    context: CaseContext,
    model: Any,
    labels: Any,
    forward: ForwardFunction,
    *,
    retain_activations: bool,
) -> tuple[Any, float, dict[str, Any]]:
    import torch

    was_training = model.training
    model.eval()
    with torch.no_grad(), context.autocast():
        logits, activations = forward(model, retain_activations)
        loss = torch.nn.functional.cross_entropy(logits, labels)
    model.train(was_training)
    return (
        logits.detach().clone(),
        float(loss.detach().cpu().item()),
        {name: value.detach().clone() for name, value in activations.items()},
    )


def run_composite_block(
    context: CaseContext,
    recorder: ObservationRecorder,
    *,
    model_name: str,
    model: Any,
    labels: Any,
    forward: ForwardFunction,
    optimiser_settings: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Run a fixed short optimisation path and retain each diagnostic checkpoint."""

    import torch

    optimisation_steps = int(BLOCK_TESTS["optimisation_steps"])
    checkpoint_steps = tuple(int(value) for value in BLOCK_TESTS["checkpoint_steps"])
    optimizer = _build_optimizer(model_name, model, optimiser_settings)
    scaler = make_grad_scaler(context) if context.profile_id == "amp_fp16" else None

    initial_logits, initial_loss, initial_activations = _evaluation(
        context,
        model,
        labels,
        forward,
        retain_activations=True,
    )
    initial_forward: dict[str, Any] = {
        "logits": initial_logits,
        "loss": torch.tensor(initial_loss, device=initial_logits.device, dtype=torch.float64),
    }
    initial_forward.update(
        {f"activation.{name}": value for name, value in initial_activations.items()}
    )

    loss_series = [initial_loss]
    parameter_states: dict[str, Any] = {"step_0": clone_named_parameters(model)}
    evaluation_outputs: dict[str, Any] = {"step_0": {"logits": initial_logits}}
    first_gradients: dict[str, Any] | None = None

    model.train()
    for step in range(optimisation_steps):
        optimizer.zero_grad(set_to_none=True)
        with context.autocast():
            logits, _ = forward(model, False)
            loss = torch.nn.functional.cross_entropy(logits, labels)

        if scaler is None:
            loss.backward()
        else:
            scaler.scale(loss).backward()
            scaler.unscale_(optimizer)

        if step == 0:
            first_gradients = clone_named_gradients(model)

        if scaler is None:
            optimizer.step()
        else:
            scaler.step(optimizer)
            scaler.update()

        checkpoint = step + 1
        if checkpoint in checkpoint_steps:
            checkpoint_logits, checkpoint_loss, _ = _evaluation(
                context,
                model,
                labels,
                forward,
                retain_activations=False,
            )
            loss_series.append(checkpoint_loss)
            parameter_states[f"step_{checkpoint}"] = clone_named_parameters(model)
            evaluation_outputs[f"step_{checkpoint}"] = {"logits": checkpoint_logits}

    if first_gradients is None:
        raise RuntimeError("The composite block did not execute a backward pass")
    if len(loss_series) != len(checkpoint_steps):
        raise RuntimeError("Composite-model loss checkpoints do not match the configured steps")

    recorder.record("initial_forward", initial_forward)
    recorder.record("loss_series", loss_series)
    recorder.record("first_gradients", first_gradients)
    recorder.record("parameter_states", parameter_states)
    recorder.record("evaluation_outputs", evaluation_outputs)

    return {
        "initial_forward": initial_forward,
        "loss_series": loss_series,
        "first_gradients": first_gradients,
        "parameter_states": parameter_states,
        "evaluation_outputs": evaluation_outputs,
    }
