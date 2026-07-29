"""Train the fixed MLP on the prepared breast-cancer dataset."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import WORKLOADS
from cases.common import (
    WorkloadBatch,
    as_profile_tensor,
    build_mlp,
    load_module_state,
    load_prepared_npz,
    module_to_profile,
    run_registered_case,
    run_training_workload,
)
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

WORKLOAD_NAME = "tabular_classification"
DATASET_ID = str(WORKLOADS[WORKLOAD_NAME]["dataset_id"])


def _case(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    training = load_prepared_npz(context, DATASET_ID, "train.npz")
    evaluation = load_prepared_npz(context, DATASET_ID, "evaluation.npz")
    model = module_to_profile(context, build_mlp())
    load_module_state(
        context,
        model,
        str(WORKLOADS[WORKLOAD_NAME]["initial_state_file"]),
    )

    def build_training_batch(rows: object) -> WorkloadBatch:
        features = as_profile_tensor(context, training["features"][rows])
        labels = as_profile_tensor(context, training["labels"][rows], dtype=torch.int64)
        return WorkloadBatch((features,), {}, labels)

    def build_evaluation_batch(rows: object) -> WorkloadBatch:
        features = as_profile_tensor(context, evaluation["features"][rows])
        labels = as_profile_tensor(context, evaluation["labels"][rows], dtype=torch.int64)
        return WorkloadBatch((features,), {}, labels)

    def forward(current_model: object, batch: WorkloadBatch) -> object:
        return current_model(*batch.args, **batch.kwargs)

    run_training_workload(
        context,
        recorder,
        workload_name=WORKLOAD_NAME,
        model=model,
        training_sample_count=len(training["labels"]),
        evaluation_sample_count=len(evaluation["labels"]),
        training_source_indices=training["source_indices"],
        build_training_batch=build_training_batch,
        build_evaluation_batch=build_evaluation_batch,
        forward=forward,
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "breast_cancer_mlp": _case,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run the tabular workload selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
