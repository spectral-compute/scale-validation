"""Special mathematical function cases over bounded canonical inputs."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _inputs(context: CaseContext) -> dict[str, object]:
    arrays = load_prepared_npz(context, DATASET_ID, "special_functions.npz")
    return {
        name: as_profile_tensor(context, value)
        for name, value in arrays.items()
    }


def _record(recorder: ObservationRecorder, values: dict[str, object]) -> None:
    recorder.record("results", values)


def _erf_family(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    signed = _inputs(context)["signed"]
    inverse_input = torch.tanh(signed / 4.0) * 0.95
    _record(
        recorder,
        {
            "erf": torch.erf(signed),
            "erfc": torch.erfc(signed),
            "erfinv": torch.erfinv(inverse_input),
        },
    )


def _gamma_family(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    gamma_inputs = _inputs(context)["gamma_inputs"]
    _record(
        recorder,
        {
            "lgamma": torch.lgamma(gamma_inputs),
            "gammaln": torch.special.gammaln(gamma_inputs),
            "digamma": torch.digamma(gamma_inputs),
            "polygamma_one": torch.polygamma(1, gamma_inputs),
        },
    )


def _softmax_and_log_softmax(
    context: CaseContext,
    recorder: ObservationRecorder,
) -> None:
    import torch

    matrix = _inputs(context)["softmax_matrix"]
    _record(
        recorder,
        {
            "softmax_rows": torch.softmax(matrix, dim=1),
            "log_softmax_rows": torch.log_softmax(matrix, dim=1),
            "logsumexp_rows": torch.logsumexp(matrix, dim=1),
            "softmax_columns": torch.softmax(matrix, dim=0),
        },
    )


def _logit_and_expit(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    probabilities = _inputs(context)["probabilities"]
    logits = torch.logit(probabilities)
    _record(
        recorder,
        {
            "logit": logits,
            "expit": torch.special.expit(logits),
            "sigmoid": torch.sigmoid(logits),
            "logit_with_epsilon": torch.logit(probabilities, eps=1e-5),
        },
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "erf_family": _erf_family,
    "gamma_family": _gamma_family,
    "softmax_and_log_softmax": _softmax_and_log_softmax,
    "logit_and_expit": _logit_and_expit,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one special-function case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
