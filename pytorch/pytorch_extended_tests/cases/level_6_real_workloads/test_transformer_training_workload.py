"""Train the fixed Transformer on the prepared SMS spam dataset."""

from __future__ import annotations

from collections.abc import Callable

from config.suite_config import WORKLOADS
from cases.common import (
    WorkloadBatch,
    as_profile_tensor,
    build_sms_transformer,
    load_module_state,
    load_prepared_npz,
    module_to_profile,
    run_registered_case,
    run_training_workload,
)
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

WORKLOAD_NAME = "transformer_sequence_classification"
DATASET_ID = str(WORKLOADS[WORKLOAD_NAME]["dataset_id"])


def _case(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    training = load_prepared_npz(context, DATASET_ID, "train.npz")
    evaluation = load_prepared_npz(context, DATASET_ID, "evaluation.npz")
    model = module_to_profile(context, build_sms_transformer())
    load_module_state(
        context,
        model,
        str(WORKLOADS[WORKLOAD_NAME]["initial_state_file"]),
    )

    def make_batch(dataset: dict[str, object], rows: object) -> WorkloadBatch:
        input_ids = as_profile_tensor(context, dataset["input_ids"][rows], dtype=torch.int64)
        attention_mask = as_profile_tensor(
            context,
            dataset["attention_mask"][rows],
            dtype=torch.bool,
        )
        labels = as_profile_tensor(context, dataset["labels"][rows], dtype=torch.int64)
        return WorkloadBatch((input_ids, attention_mask), {}, labels)

    def build_training_batch(rows: object) -> WorkloadBatch:
        return make_batch(training, rows)

    def build_evaluation_batch(rows: object) -> WorkloadBatch:
        return make_batch(evaluation, rows)

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
    "sms_spam_transformer": _case,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run the Transformer workload selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
