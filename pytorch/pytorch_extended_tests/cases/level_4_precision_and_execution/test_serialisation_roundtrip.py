"""Save and reload tensors, models, optimiser state and complete checkpoints."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from pathlib import Path
from typing import Any

from config.suite_config import LEVEL_4_TESTS
from cases.common import (
    as_profile_tensor,
    build_mlp,
    clone_module_state,
    flatten_optimizer_state,
    load_module_state,
    load_prepared_npz,
    module_to_profile,
    run_registered_case,
)
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder


DATASET_ID = "model_inputs_v1"


def _load(path: Path, *, map_location: str) -> Any:
    import torch

    try:
        return torch.load(path, map_location=map_location, weights_only=True)
    except TypeError:
        # weights_only was added after some older PyTorch releases
        # The saved objects here are still only tensors and basic Python values
        return torch.load(path, map_location=map_location)


def _tensor_structure(values: Mapping[str, Any]) -> dict[str, Any]:
    import torch

    structure: dict[str, Any] = {}
    for name, value in values.items():
        if isinstance(value, torch.Tensor):
            structure[name] = {
                "kind": "tensor",
                "shape": list(value.shape),
                "dtype": str(value.dtype).removeprefix("torch."),
            }
        else:
            structure[name] = {"kind": type(value).__name__, "value": value}
    return structure


def _flatten_loaded_optimizer(optimizer: Any, model: Any) -> dict[str, Any]:
    return flatten_optimizer_state(optimizer, model)


def _fixed_batch(context: CaseContext) -> tuple[Any, Any]:
    import torch

    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    value = as_profile_tensor(context, arrays["mlp_input"])
    labels = as_profile_tensor(context, arrays["mlp_labels"], dtype=torch.int64)
    return value, labels


def _new_model(context: CaseContext) -> Any:
    model = module_to_profile(context, build_mlp())
    load_module_state(context, model, "mlp_initial_state.npz")
    return model


def _tensor_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    value, labels = _fixed_batch(context)
    payload = {
        "input": value,
        "labels": labels,
        "projection": torch.arange(
            value.shape[1] * 7,
            device=context.device,
            dtype=context.torch_dtype(),
        ).reshape(value.shape[1], 7)
        / 100.0,
    }
    path = context.temporary_directory / "tensor_bundle.pt"
    torch.save(payload, path)
    loaded = _load(path, map_location=context.device)
    model = _new_model(context)
    with torch.no_grad():
        logits = model(loaded["input"])
        projection = loaded["input"] @ loaded["projection"]

    recorder.record("structure", _tensor_structure(loaded))
    recorder.record("loaded_values", dict(loaded))
    recorder.record("post_load_forward", {"logits": logits, "projection": projection})


def _model_state_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    value, _ = _fixed_batch(context)
    model = _new_model(context)
    path = context.temporary_directory / "model_state.pt"
    torch.save(model.state_dict(), path)
    loaded_state = _load(path, map_location=context.device)
    reloaded = module_to_profile(context, build_mlp())
    reloaded.load_state_dict(loaded_state, strict=True)
    with torch.no_grad():
        logits = reloaded(value)

    recorder.record("structure", _tensor_structure(loaded_state))
    recorder.record("loaded_values", dict(loaded_state))
    recorder.record("post_load_forward", {"logits": logits})


def _trained_model_and_optimizer(context: CaseContext) -> tuple[Any, Any, Any, Any]:
    import torch

    value, labels = _fixed_batch(context)
    model = _new_model(context)
    settings = LEVEL_4_TESTS["serialisation"]
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=float(settings["learning_rate"]),
        betas=tuple(settings["betas"]),
        eps=float(settings["epsilon"]),
        weight_decay=float(settings["weight_decay"]),
    )
    optimizer.zero_grad(set_to_none=True)
    logits = model(value)
    loss = torch.nn.functional.cross_entropy(logits, labels)
    loss.backward()
    optimizer.step()
    return model, optimizer, value, labels


def _optimizer_state_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    model, optimizer, value, _ = _trained_model_and_optimizer(context)
    path = context.temporary_directory / "optimizer_state.pt"
    torch.save(
        {"model": model.state_dict(), "optimizer": optimizer.state_dict()},
        path,
    )
    loaded = _load(path, map_location=context.device)
    reloaded_model = module_to_profile(context, build_mlp())
    reloaded_model.load_state_dict(loaded["model"], strict=True)
    settings = LEVEL_4_TESTS["serialisation"]
    reloaded_optimizer = torch.optim.AdamW(
        reloaded_model.parameters(),
        lr=float(settings["learning_rate"]),
        betas=tuple(settings["betas"]),
        eps=float(settings["epsilon"]),
        weight_decay=float(settings["weight_decay"]),
    )
    reloaded_optimizer.load_state_dict(loaded["optimizer"])
    with torch.no_grad():
        logits = reloaded_model(value)

    loaded_values = {
        **{f"model.{name}": tensor for name, tensor in clone_module_state(reloaded_model).items()},
        **{
            f"optimizer.{name}": tensor
            for name, tensor in _flatten_loaded_optimizer(
                reloaded_optimizer, reloaded_model
            ).items()
        },
    }
    structure = {
        "top_level_keys": sorted(loaded),
        "model": _tensor_structure(loaded["model"]),
        "optimizer_param_group_count": len(loaded["optimizer"]["param_groups"]),
        "optimizer_state_entry_count": len(loaded["optimizer"]["state"]),
    }
    recorder.record("structure", structure)
    recorder.record("loaded_values", loaded_values)
    recorder.record("post_load_forward", {"logits": logits})


def _complete_checkpoint_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    model, optimizer, value, labels = _trained_model_and_optimizer(context)
    with torch.no_grad():
        checkpoint_loss = torch.nn.functional.cross_entropy(model(value), labels)
    checkpoint = {
        "format_version": str(LEVEL_4_TESTS["serialisation"]["checkpoint_version"]),
        "step": int(LEVEL_4_TESTS["serialisation"]["checkpoint_step"]),
        "model": model.state_dict(),
        "optimizer": optimizer.state_dict(),
        "loss": checkpoint_loss.detach(),
        "cpu_rng_state": torch.get_rng_state(),
    }
    path = context.temporary_directory / "complete_checkpoint.pt"
    torch.save(checkpoint, path)
    loaded = _load(path, map_location=context.device)

    reloaded_model = module_to_profile(context, build_mlp())
    reloaded_model.load_state_dict(loaded["model"], strict=True)
    settings = LEVEL_4_TESTS["serialisation"]
    reloaded_optimizer = torch.optim.AdamW(
        reloaded_model.parameters(),
        lr=float(settings["learning_rate"]),
        betas=tuple(settings["betas"]),
        eps=float(settings["epsilon"]),
        weight_decay=float(settings["weight_decay"]),
    )
    reloaded_optimizer.load_state_dict(loaded["optimizer"])
    with torch.no_grad():
        logits = reloaded_model(value)
        loss = torch.nn.functional.cross_entropy(logits, labels)

    loaded_values = {
        **{f"model.{name}": tensor for name, tensor in clone_module_state(reloaded_model).items()},
        **{
            f"optimizer.{name}": tensor
            for name, tensor in _flatten_loaded_optimizer(
                reloaded_optimizer, reloaded_model
            ).items()
        },
        "checkpoint.loss": loaded["loss"],
        "checkpoint.cpu_rng_state": loaded["cpu_rng_state"],
        "checkpoint.step": torch.tensor(
            loaded["step"], device=context.device, dtype=torch.int64
        ),
    }
    structure = {
        "top_level_keys": sorted(loaded),
        "format_version": loaded["format_version"],
        "step": int(loaded["step"]),
        "model": _tensor_structure(loaded["model"]),
        "optimizer_param_group_count": len(loaded["optimizer"]["param_groups"]),
        "optimizer_state_entry_count": len(loaded["optimizer"]["state"]),
    }
    recorder.record("structure", structure)
    recorder.record("loaded_values", loaded_values)
    recorder.record("post_load_forward", {"logits": logits, "loss": loss.detach()})


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "tensor": _tensor_case,
    "model_state": _model_state_case,
    "optimizer_state": _optimizer_state_case,
    "complete_checkpoint": _complete_checkpoint_case,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one serialisation round trip selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
