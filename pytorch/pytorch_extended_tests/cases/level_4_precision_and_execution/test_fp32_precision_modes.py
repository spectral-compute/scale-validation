"""Exercise float32 matmul and convolution under each configured precision mode."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import PRECISION_MODE_CASES
from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder
from pytorch_extended_tests.precision_settings import (
    apply_float32_precision,
    float32_precision_record,
)


DATASET_ID = "numerical_inputs_v1"


def _case(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch
    import torch.nn.functional as functional

    matrix_arrays = load_prepared_npz(context, DATASET_ID, "matrix_operations.npz")
    convolution_arrays = load_prepared_npz(context, DATASET_ID, "convolutions.npz")
    settings = dict(PRECISION_MODE_CASES[context.case_id])
    original = float32_precision_record()

    try:
        apply_float32_precision(
            allow_tf32=bool(settings["allow_tf32"]),
            matmul_precision=str(settings["float32_matmul_precision"]),
        )
        left = as_profile_tensor(context, matrix_arrays["left"], dtype=torch.float32)
        right = as_profile_tensor(context, matrix_arrays["right"], dtype=torch.float32)
        batch_left = as_profile_tensor(context, matrix_arrays["batch_left"], dtype=torch.float32)
        batch_right = as_profile_tensor(context, matrix_arrays["batch_right"], dtype=torch.float32)

        conv_input = as_profile_tensor(
            context, convolution_arrays["conv2d_input"], dtype=torch.float32
        )
        conv_weight = as_profile_tensor(
            context, convolution_arrays["conv2d_weight"], dtype=torch.float32
        )
        conv_bias = as_profile_tensor(
            context, convolution_arrays["conv2d_bias"], dtype=torch.float32
        )
        grouped_input = as_profile_tensor(
            context, convolution_arrays["grouped_conv2d_input"], dtype=torch.float32
        )
        grouped_weight = as_profile_tensor(
            context, convolution_arrays["grouped_conv2d_weight"], dtype=torch.float32
        )
        grouped_bias = as_profile_tensor(
            context, convolution_arrays["grouped_conv2d_bias"], dtype=torch.float32
        )

        matrix_results = {
            "matmul": torch.matmul(left, right),
            "batched_matmul": torch.matmul(batch_left, batch_right),
            "linear_equivalent": functional.linear(left, right.transpose(0, 1)),
        }
        convolution_results = {
            "conv2d": functional.conv2d(conv_input, conv_weight, conv_bias, padding=1),
            "grouped_conv2d": functional.conv2d(
                grouped_input,
                grouped_weight,
                grouped_bias,
                padding=1,
                groups=2,
            ),
        }
        applied = {
            "case_id": context.case_id,
            "device_type": torch.device(context.device).type,
            "requested_allow_tf32": bool(settings["allow_tf32"]),
            "requested_float32_matmul_precision": str(
                settings["float32_matmul_precision"]
            ),
            **float32_precision_record(),
        }

        recorder.record("matrix_results", matrix_results)
        recorder.record("convolution_results", convolution_results)
        recorder.record("applied_settings", applied)
    finally:
        original_convolution_precision = original["cudnn_convolution_precision"]
        apply_float32_precision(
            allow_tf32=original_convolution_precision == "tf32",
            matmul_precision=str(original["float32_matmul_precision"]),
        )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    case_id: _case for case_id in PRECISION_MODE_CASES
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one backend precision mode selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
