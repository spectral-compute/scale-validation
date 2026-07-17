"""Small dispatch helper shared by case files."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from typing import Any

from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

CaseFunction = Callable[[CaseContext, ObservationRecorder], None]


def run_registered_case(
    context: CaseContext,
    recorder: ObservationRecorder,
    cases: Mapping[str, CaseFunction],
) -> None:
    """Run the function registered for the current catalogue case ID."""

    try:
        case_function = cases[context.case_id]
    except KeyError as exc:
        known = ", ".join(sorted(cases))
        raise KeyError(
            f"No implementation is registered for {context.case_id!r}\n"
            f"Known cases: {known}"
        ) from exc

    case_function(context, recorder)
