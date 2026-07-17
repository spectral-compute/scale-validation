"""Attention forward and backward cases with fixed projections and masks."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import MODEL_ARCHITECTURES
from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "model_inputs_v1"


def _inputs(context: CaseContext) -> tuple[object, object, dict[str, object]]:
    arrays = load_prepared_npz(context, DATASET_ID, "block_inputs.npz")
    state_arrays = load_prepared_npz(context, DATASET_ID, "attention_initial_state.npz")
    value = as_profile_tensor(context, arrays["attention_input"], requires_grad=True)
    mask = as_profile_tensor(context, arrays["attention_padding_mask"])
    state = {name: as_profile_tensor(context, array) for name, array in state_arrays.items()}
    return value, mask, state


def _functional_attention(
    context: CaseContext,
    recorder: ObservationRecorder,
    *,
    use_mask: bool,
) -> None:
    import math
    import torch

    value, padding_mask, state = _inputs(context)
    architecture = MODEL_ARCHITECTURES["attention"]
    head_count = architecture["heads"]
    head_size = architecture["embedding_size"] // head_count

    q_weight = state["q_proj.weight"].detach().clone().requires_grad_(True)
    k_weight = state["k_proj.weight"].detach().clone().requires_grad_(True)
    v_weight = state["v_proj.weight"].detach().clone().requires_grad_(True)
    q_bias = state["q_proj.bias"].detach().clone().requires_grad_(True)
    k_bias = state["k_proj.bias"].detach().clone().requires_grad_(True)
    v_bias = state["v_proj.bias"].detach().clone().requires_grad_(True)

    query = torch.nn.functional.linear(value, q_weight, q_bias)
    key = torch.nn.functional.linear(value, k_weight, k_bias)
    projected_value = torch.nn.functional.linear(value, v_weight, v_bias)

    def split_heads(tensor: object) -> object:
        return tensor.reshape(tensor.shape[0], tensor.shape[1], head_count, head_size).transpose(1, 2)

    query_heads = split_heads(query)
    key_heads = split_heads(key)
    value_heads = split_heads(projected_value)
    scores = query_heads @ key_heads.transpose(-2, -1) / math.sqrt(head_size)
    if use_mask:
        # Keep at least one key visible even if a prepared row was fully masked
        padding_mask = padding_mask.clone()
        padding_mask[:, 0] = False
        scores = scores.masked_fill(padding_mask[:, None, None, :], float("-inf"))
    weights = torch.softmax(scores, dim=-1)
    attended = weights @ value_heads
    output = attended.transpose(1, 2).contiguous().reshape_as(value)
    loss = output.square().mean()
    loss.backward()

    recorder.record(
        "forward",
        {
            "query": query,
            "key": key,
            "value": projected_value,
            "attention_weights": weights,
            "output": output,
        },
    )
    recorder.record("loss", float(loss.detach().cpu().item()))
    recorder.record("input_gradients", {"value": value.grad.detach().clone()})
    recorder.record(
        "parameter_gradients",
        {
            "q_weight": q_weight.grad.detach().clone(),
            "k_weight": k_weight.grad.detach().clone(),
            "v_weight": v_weight.grad.detach().clone(),
            "q_bias": q_bias.grad.detach().clone(),
            "k_bias": k_bias.grad.detach().clone(),
            "v_bias": v_bias.grad.detach().clone(),
        },
    )


def _scaled_dot_product(context: CaseContext, recorder: ObservationRecorder) -> None:
    _functional_attention(context, recorder, use_mask=False)


def _masked_scaled_dot_product(context: CaseContext, recorder: ObservationRecorder) -> None:
    _functional_attention(context, recorder, use_mask=True)


def _multihead_attention(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    value, padding_mask, state = _inputs(context)
    architecture = MODEL_ARCHITECTURES["attention"]
    module = torch.nn.MultiheadAttention(
        architecture["embedding_size"],
        architecture["heads"],
        dropout=0.0,
        batch_first=True,
    ).to(device=context.device, dtype=context.torch_dtype())
    with torch.no_grad():
        module.in_proj_weight.copy_(
            torch.cat(
                [state["q_proj.weight"], state["k_proj.weight"], state["v_proj.weight"]],
                dim=0,
            )
        )
        module.in_proj_bias.copy_(
            torch.cat(
                [state["q_proj.bias"], state["k_proj.bias"], state["v_proj.bias"]],
                dim=0,
            )
        )
        module.out_proj.weight.copy_(state["out_proj.weight"])
        module.out_proj.bias.copy_(state["out_proj.bias"])
    padding_mask = padding_mask.clone()
    padding_mask[:, 0] = False
    output, weights = module(
        value,
        value,
        value,
        key_padding_mask=padding_mask,
        need_weights=True,
        average_attn_weights=False,
    )
    loss = output.square().mean()
    loss.backward()
    recorder.record("forward", {"output": output, "attention_weights": weights})
    recorder.record("loss", float(loss.detach().cpu().item()))
    recorder.record("input_gradients", {"value": value.grad.detach().clone()})
    recorder.record(
        "parameter_gradients",
        {
            name: parameter.grad.detach().clone()
            for name, parameter in module.named_parameters()
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "scaled_dot_product": _scaled_dot_product,
    "masked_scaled_dot_product": _masked_scaled_dot_product,
    "multihead_attention": _multihead_attention,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one attention case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
