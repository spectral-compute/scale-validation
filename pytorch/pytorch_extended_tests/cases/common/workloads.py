"""Shared training and evaluation loop for the Level 6 workloads."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass
from typing import Any

import numpy as np

from config.suite_config import DATALOADER, OUTPUT_CAPTURE, WORKLOAD_CAPTURE, WORKLOADS
from cases.common.learning import (
    clone_named_gradients,
    clone_named_parameters,
    flatten_optimizer_state,
)
from cases.common.mixed_precision import make_grad_scaler
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder


@dataclass(frozen=True, slots=True)
class WorkloadBatch:
    """One model batch with positional inputs, keyword inputs and labels."""

    args: tuple[Any, ...]
    kwargs: Mapping[str, Any]
    labels: Any


BatchBuilder = Callable[[np.ndarray], WorkloadBatch]
ForwardFunction = Callable[[Any, WorkloadBatch], Any]


def _build_optimizer(settings: Mapping[str, Any], model: Any) -> Any:
    import torch

    optimiser_name = str(settings["optimiser"])
    if optimiser_name == "sgd":
        return torch.optim.SGD(
            model.parameters(),
            lr=float(settings["learning_rate"]),
            momentum=float(settings["momentum"]),
            weight_decay=float(settings["weight_decay"]),
        )
    if optimiser_name == "adamw":
        return torch.optim.AdamW(
            model.parameters(),
            lr=float(settings["learning_rate"]),
            betas=tuple(float(value) for value in settings["betas"]),
            eps=float(settings["epsilon"]),
            weight_decay=float(settings["weight_decay"]),
        )
    raise ValueError(f"Unknown workload optimiser: {optimiser_name}")


def _batch_schedule(
    *,
    sample_count: int,
    batch_size: int,
    step_count: int,
    seed: int,
    shuffle: bool,
    drop_last: bool,
) -> tuple[np.ndarray, ...]:
    """Build the exact training rows used by every optimisation step."""

    if sample_count < 1:
        raise ValueError("The training dataset must contain at least one sample")
    if batch_size < 1:
        raise ValueError("The training batch size must be positive")
    if drop_last and sample_count < batch_size:
        raise ValueError("drop_last cannot be used when the dataset is smaller than one batch")

    generator = np.random.Generator(np.random.PCG64(seed))
    batches: list[np.ndarray] = []
    order = np.arange(sample_count, dtype=np.int64)
    position = sample_count

    for _ in range(step_count):
        if position >= sample_count or (drop_last and position + batch_size > sample_count):
            order = (
                generator.permutation(sample_count).astype(np.int64, copy=False)
                if shuffle
                else np.arange(sample_count, dtype=np.int64)
            )
            position = 0

        stop = min(position + batch_size, sample_count)
        batches.append(np.array(order[position:stop], dtype=np.int64, copy=True))
        position = stop

    return tuple(batches)


def _evaluation_rows(sample_count: int, batch_size: int) -> tuple[np.ndarray, ...]:
    rows = np.arange(sample_count, dtype=np.int64)
    return tuple(
        np.array(rows[start : start + batch_size], copy=True)
        for start in range(0, sample_count, batch_size)
    )


def _evaluate(
    context: CaseContext,
    model: Any,
    *,
    rows: tuple[np.ndarray, ...],
    build_batch: BatchBuilder,
    forward: ForwardFunction,
) -> tuple[Any, float, Any, int]:
    import torch

    was_training = model.training
    model.eval()
    logits_parts: list[Any] = []
    label_parts: list[Any] = []
    with torch.no_grad():
        for row_indices in rows:
            batch = build_batch(row_indices)
            with context.autocast():
                logits = forward(model, batch)
            logits_parts.append(logits.detach())
            label_parts.append(batch.labels.detach())

    logits = torch.cat(logits_parts, dim=0)
    labels = torch.cat(label_parts, dim=0)
    with context.autocast():
        loss = torch.nn.functional.cross_entropy(logits, labels)
    predictions = torch.argmax(logits, dim=1)
    correct = int((predictions == labels).sum().detach().cpu().item())
    model.train(was_training)
    return logits.clone(), float(loss.detach().cpu().item()), predictions.clone(), correct


def _metric_tensors(
    *,
    loss: float,
    correct_count: int,
    sample_count: int,
    device: Any,
) -> dict[str, Any]:
    import torch

    return {
        "loss": torch.tensor(loss, dtype=torch.float64, device=device),
        "accuracy": torch.tensor(
            correct_count / sample_count,
            dtype=torch.float64,
            device=device,
        ),
        "correct_count": torch.tensor(correct_count, dtype=torch.int64, device=device),
        "sample_count": torch.tensor(sample_count, dtype=torch.int64, device=device),
    }


def _optimizer_snapshot(optimizer: Any, model: Any, scaler: Any | None) -> dict[str, Any]:
    import torch

    output: dict[str, Any] = {
        "optimizer": flatten_optimizer_state(optimizer, model),
    }
    if scaler is not None:
        reference = next(model.parameters())
        state = scaler.state_dict()
        output["grad_scaler"] = {
            "scale": torch.tensor(
                float(scaler.get_scale()),
                dtype=torch.float64,
                device=reference.device,
            ),
            "growth_factor": torch.tensor(
                float(state.get("growth_factor", 1.0)),
                dtype=torch.float64,
                device=reference.device,
            ),
            "backoff_factor": torch.tensor(
                float(state.get("backoff_factor", 1.0)),
                dtype=torch.float64,
                device=reference.device,
            ),
            "growth_interval": torch.tensor(
                int(state.get("growth_interval", 0)),
                dtype=torch.int64,
                device=reference.device,
            ),
            "growth_tracker": torch.tensor(
                int(state.get("_growth_tracker", 0)),
                dtype=torch.int64,
                device=reference.device,
            ),
        }
    return output


def run_training_workload(
    context: CaseContext,
    recorder: ObservationRecorder,
    *,
    workload_name: str,
    model: Any,
    training_sample_count: int,
    evaluation_sample_count: int,
    training_source_indices: np.ndarray,
    build_training_batch: BatchBuilder,
    build_evaluation_batch: BatchBuilder,
    forward: ForwardFunction,
) -> None:
    """Run one fixed step-limited workload and retain its diagnostic outputs."""

    import torch

    settings = WORKLOADS[workload_name]
    training_steps = int(settings["training_steps"])
    checkpoint_steps = tuple(int(value) for value in settings["checkpoint_steps"])
    early_steps = set(int(value) for value in WORKLOAD_CAPTURE["early_parameter_state_steps"])
    optimizer = _build_optimizer(settings, model)
    scaler = make_grad_scaler(context) if context.profile_id == "amp_fp16" else None

    batch_rows = _batch_schedule(
        sample_count=training_sample_count,
        batch_size=int(settings["batch_size"]),
        step_count=training_steps,
        seed=context.seed_for("training_order"),
        shuffle=bool(settings["shuffle_training_data"]),
        drop_last=bool(DATALOADER["drop_last"]),
    )
    evaluation_rows = _evaluation_rows(
        evaluation_sample_count,
        int(settings["evaluation_batch_size"]),
    )

    initial_logits, initial_loss, initial_predictions, initial_correct = _evaluate(
        context,
        model,
        rows=evaluation_rows,
        build_batch=build_evaluation_batch,
        forward=forward,
    )

    checkpoint_logits: dict[str, Any] = {"step_0": initial_logits}
    checkpoint_metrics: dict[str, Any] = {
        "step_0": _metric_tensors(
            loss=initial_loss,
            correct_count=initial_correct,
            sample_count=evaluation_sample_count,
            device=initial_logits.device,
        )
    }
    early_parameter_states: dict[str, Any] = {}
    if 0 in early_steps:
        early_parameter_states["step_0"] = clone_named_parameters(model)

    optimizer_states: dict[str, Any] = {}
    if OUTPUT_CAPTURE["store_optimizer_state"]:
        optimizer_states["step_0"] = _optimizer_snapshot(optimizer, model, scaler)

    training_losses: list[float] = []
    training_batch_indices: dict[str, Any] = {}
    first_gradients: dict[str, Any] | None = None

    model.train()
    for step_index, row_indices in enumerate(batch_rows, start=1):
        batch = build_training_batch(row_indices)
        source_rows = np.asarray(training_source_indices[row_indices], dtype=np.int64)
        training_batch_indices[f"step_{step_index}"] = torch.from_numpy(
            np.ascontiguousarray(source_rows)
        )

        optimizer.zero_grad(set_to_none=True)
        with context.autocast():
            logits = forward(model, batch)
            loss = torch.nn.functional.cross_entropy(logits, batch.labels)

        if scaler is None:
            loss.backward()
        else:
            scaler.scale(loss).backward()
            scaler.unscale_(optimizer)

        if step_index == 1:
            first_gradients = clone_named_gradients(model)

        if scaler is None:
            optimizer.step()
        else:
            scaler.step(optimizer)
            scaler.update()

        training_losses.append(float(loss.detach().cpu().item()))

        if step_index in early_steps:
            early_parameter_states[f"step_{step_index}"] = clone_named_parameters(model)

        if step_index in checkpoint_steps:
            logits_at_step, loss_at_step, _, correct_at_step = _evaluate(
                context,
                model,
                rows=evaluation_rows,
                build_batch=build_evaluation_batch,
                forward=forward,
            )
            checkpoint_logits[f"step_{step_index}"] = logits_at_step
            checkpoint_metrics[f"step_{step_index}"] = _metric_tensors(
                loss=loss_at_step,
                correct_count=correct_at_step,
                sample_count=evaluation_sample_count,
                device=logits_at_step.device,
            )
            if OUTPUT_CAPTURE["store_optimizer_state"]:
                optimizer_states[f"step_{step_index}"] = _optimizer_snapshot(
                    optimizer,
                    model,
                    scaler,
                )

    if first_gradients is None:
        raise RuntimeError("The workload did not execute its first backward pass")
    missing_checkpoints = {
        f"step_{step}" for step in checkpoint_steps
    } - set(checkpoint_logits)
    if missing_checkpoints:
        raise RuntimeError(f"Workload did not produce checkpoints: {sorted(missing_checkpoints)}")

    final_logits = checkpoint_logits[f"step_{training_steps}"]
    final_predictions = torch.argmax(final_logits, dim=1)
    final_metric_tensors = checkpoint_metrics[f"step_{training_steps}"]
    final_loss = float(final_metric_tensors["loss"].detach().cpu().item())
    final_correct = int(final_metric_tensors["correct_count"].detach().cpu().item())

    recorder.record("initial_logits", initial_logits)
    recorder.record("initial_loss", initial_loss)
    recorder.record("training_loss", training_losses)
    recorder.record("training_batch_indices", training_batch_indices)
    recorder.record("checkpoint_logits", checkpoint_logits)
    recorder.record("checkpoint_metrics", checkpoint_metrics)
    recorder.record("first_gradients", first_gradients)
    recorder.record("early_parameter_states", early_parameter_states)
    if OUTPUT_CAPTURE["store_optimizer_state"]:
        recorder.record("optimizer_states", optimizer_states)
    if OUTPUT_CAPTURE["store_final_parameters"]:
        recorder.record("final_parameters", clone_named_parameters(model))
    recorder.record("final_predictions", final_predictions)
    recorder.record(
        "final_metrics",
        {
            "dataset_id": str(settings["dataset_id"]),
            "training_steps": training_steps,
            "training_batch_size": int(settings["batch_size"]),
            "evaluation_batch_size": int(settings["evaluation_batch_size"]),
            "training_sample_count": training_sample_count,
            "evaluation_sample_count": evaluation_sample_count,
            "examples_seen": int(sum(len(rows) for rows in batch_rows)),
            "initial_evaluation_loss": initial_loss,
            "initial_correct_count": initial_correct,
            "initial_accuracy": initial_correct / evaluation_sample_count,
            "final_evaluation_loss": final_loss,
            "final_correct_count": final_correct,
            "final_accuracy": final_correct / evaluation_sample_count,
            "checkpoint_steps": list(checkpoint_steps),
            "initial_prediction_count": int(initial_predictions.numel()),
            "final_prediction_count": int(final_predictions.numel()),
            "grad_scaler_enabled": scaler is not None,
            "final_grad_scale": float(scaler.get_scale()) if scaler is not None else None,
        },
    )
