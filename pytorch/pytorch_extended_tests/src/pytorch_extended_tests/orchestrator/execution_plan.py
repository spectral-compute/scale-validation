"""Build the ordered list of test-module/profile tasks for one invocation."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Iterable

from config.suite_config import (
    DEFAULT_PROFILES_BY_DEVICE,
    EXECUTION,
    EXECUTION_PROFILES,
    LEVELS,
)
from config.test_catalogue import TEST_CATALOGUE, TestSpec


@dataclass(frozen=True, slots=True)
class ExecutionTask:
    """One test module running all of its cases under one profile."""

    task_id: str
    test_id: str
    profile_id: str
    device: str
    case_ids: tuple[str, ...]
    observations_relative_path: str
    status_relative_path: str

    def as_dict(self) -> dict[str, object]:
        return asdict(self)


def _normalise_selection(
    requested: Iterable[str] | None,
    *,
    defaults: tuple[str, ...],
    allowed: set[str],
    label: str,
) -> tuple[str, ...]:
    values = defaults if requested is None else tuple(dict.fromkeys(requested))
    unknown = set(values) - allowed
    if unknown:
        raise ValueError(f"Unknown {label}: {sorted(unknown)}")
    return tuple(values)


def select_test_specs(
    *,
    levels: Iterable[str] | None,
    test_ids: Iterable[str] | None,
) -> tuple[TestSpec, ...]:
    selected_levels = _normalise_selection(
        levels,
        defaults=tuple(EXECUTION["enabled_levels"]),
        allowed=set(LEVELS),
        label="test levels",
    )
    requested_test_ids = None if test_ids is None else tuple(dict.fromkeys(test_ids))

    configured_enabled = set(EXECUTION["enabled_test_ids"])
    configured_disabled = set(EXECUTION["disabled_test_ids"])
    known_test_ids = {spec.test_id for spec in TEST_CATALOGUE}

    if configured_enabled - known_test_ids:
        raise ValueError("EXECUTION enabled_test_ids contains unknown tests")
    if configured_disabled - known_test_ids:
        raise ValueError("EXECUTION disabled_test_ids contains unknown tests")
    if requested_test_ids is not None and set(requested_test_ids) - known_test_ids:
        unknown = sorted(set(requested_test_ids) - known_test_ids)
        raise ValueError(f"Unknown test IDs: {unknown}")

    selected: list[TestSpec] = []
    for spec in TEST_CATALOGUE:
        if spec.level not in selected_levels:
            continue
        if configured_enabled and spec.test_id not in configured_enabled:
            continue
        if spec.test_id in configured_disabled:
            continue
        if requested_test_ids is not None and spec.test_id not in requested_test_ids:
            continue
        selected.append(spec)
    return tuple(selected)


def build_execution_plan(
    *,
    device: str,
    profiles: Iterable[str] | None,
    levels: Iterable[str] | None,
    test_ids: Iterable[str] | None,
) -> tuple[ExecutionTask, ...]:
    selected_profiles = _normalise_selection(
        profiles,
        defaults=tuple(DEFAULT_PROFILES_BY_DEVICE[device]),
        allowed=set(EXECUTION_PROFILES),
        label="execution profiles",
    )
    test_specs = select_test_specs(levels=levels, test_ids=test_ids)

    tasks: list[ExecutionTask] = []
    for spec in test_specs:
        for profile_id in selected_profiles:
            if profile_id not in spec.profile_ids:
                continue
            index = len(tasks)
            task_name = f"{index:04d}_{spec.test_id}_{profile_id}".replace(".", "_")
            task_directory = f".work/tasks/{task_name}"
            tasks.append(
                ExecutionTask(
                    task_id=task_name,
                    test_id=spec.test_id,
                    profile_id=profile_id,
                    device=device,
                    case_ids=spec.case_ids,
                    observations_relative_path=f"{task_directory}/observations.jsonl",
                    status_relative_path=f"{task_directory}/task_status.json",
                )
            )
    return tuple(tasks)
