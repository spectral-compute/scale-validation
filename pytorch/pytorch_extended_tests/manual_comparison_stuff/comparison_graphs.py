#!/usr/bin/env python3
"""Plot training progress and inference outputs from comparison inputs."""

from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np

from analyse_repeatability import RunBundle, load_tensor


DEFAULT_REPORTING_SETTINGS = {
    "training_progress_checkpoint_count": 5,
    "training_loss_step_count": 30,
    "include_initial_checkpoint": True,
    "inference_preview_value_count": 512,
    "inference_scatter_point_count": 2_000,
    "inference_sample_error_count": 256,
}


def reporting_settings(policy: Mapping[str, Any]) -> dict[str, Any]:
    """Return reporting settings with stable defaults for older policy files."""

    output = dict(DEFAULT_REPORTING_SETTINGS)
    configured = policy.get("reporting")
    if isinstance(configured, Mapping):
        output.update(configured)
    return output


def _safe_component(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("._")
    return cleaned or "unnamed"


def _step_number(value: str) -> int | None:
    match = re.fullmatch(r"step_(\d+)", value)
    return int(match.group(1)) if match else None


def _selected_steps(values: Sequence[int], settings: Mapping[str, Any]) -> list[int]:
    ordered = sorted(set(int(value) for value in values))
    initial = [value for value in ordered if value == 0]
    trained = [value for value in ordered if value > 0]
    count = max(1, int(settings.get("training_progress_checkpoint_count", 5)))
    selected = trained[:count]
    if bool(settings.get("include_initial_checkpoint", True)):
        selected = initial[:1] + selected
    return selected


def _output_map(analysis: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    return {
        str(output.get("identity_key")): output
        for output in analysis.get("outputs", [])
        if isinstance(output, Mapping)
    }


MODEL_LEVELS = {
    "level_0_smoke_workloads",
    "level_5_composite_models",
    "level_6_real_workloads",
}


def _model_outputs(analysis: Mapping[str, Any], output_id: str) -> list[Mapping[str, Any]]:
    return [
        output
        for output in analysis.get("outputs", [])
        if isinstance(output, Mapping)
        and output.get("level") in MODEL_LEVELS
        and isinstance(output.get("identity"), Mapping)
        and output["identity"].get("output_id") == output_id
    ]


def _plot_filename(prefix: str, identity: Mapping[str, Any], suffix: str) -> str:
    parts = [
        prefix,
        str(identity.get("test_id")),
        str(identity.get("case_id")),
        str(identity.get("profile_id")),
        suffix,
    ]
    return "__".join(_safe_component(part) for part in parts) + ".png"


def _plot_title(identity: Mapping[str, Any], label: str) -> str:
    return (
        f"{identity.get('case_id')} — {label} "
        f"[{identity.get('profile_id')}]"
    )


def _environment_label(name: str, reference_environment: str = "reference") -> str:
    if name != reference_environment:
        return name
    return "reference baseline" if name == "reference" else f"{name} (reference baseline)"


def _reference_axis_label(reference_environment: str) -> str:
    if reference_environment == "reference":
        return "Reference final logit"
    return f"{reference_environment} reference final logit"


def _shared_axis_limits(values: np.ndarray) -> tuple[float, float]:
    low = float(np.min(values))
    high = float(np.max(values))
    if high > low:
        return low, high
    padding = max(abs(low) * 0.05, 1.0e-12)
    return low - padding, high + padding


def _finish_plot(figure: Any, axis: Any, title: str, caption: str) -> None:
    figure.suptitle(title, fontsize=12, fontweight="bold", y=0.985)
    figure.text(
        0.5,
        0.012,
        caption,
        ha="center",
        va="bottom",
        fontsize=8.5,
        wrap=True,
    )
    figure.tight_layout(rect=(0.0, 0.065, 1.0, 0.94))


def _environment_plot_order(names: Sequence[str], reference_environment: str) -> list[str]:
    """Plot candidates first and the reference last so exact overlaps remain visible."""

    ordered = [name for name in names if name != reference_environment]
    if reference_environment in names:
        ordered.append(reference_environment)
    return ordered


def _plot_environment_line(
    axis: Any,
    x: Sequence[float] | np.ndarray,
    y: Sequence[float] | np.ndarray,
    name: str,
    reference_environment: str,
) -> Any:
    """Draw environments with distinct encodings that survive exact curve overlap."""

    if name == reference_environment:
        return axis.plot(
            x,
            y,
            linestyle=(0, (5, 3)),
            linewidth=2.3,
            marker="o",
            markersize=6.0,
            markerfacecolor="white",
            markeredgewidth=1.5,
            label=_environment_label(name, reference_environment),
            zorder=4,
        )[0]
    return axis.plot(
        x,
        y,
        linestyle="-",
        linewidth=1.9,
        marker="s",
        markersize=5.2,
        label=_environment_label(name, reference_environment),
        zorder=3,
    )[0]


def _draw_repeatability_envelope(
    axis: Any,
    x: Sequence[float] | np.ndarray,
    lower: Sequence[float] | np.ndarray,
    upper: Sequence[float] | np.ndarray,
    line: Any,
) -> bool:
    """Draw a normal range band, or a faint halo when the range has zero height."""

    lower_values = np.asarray(lower, dtype=np.float64)
    upper_values = np.asarray(upper, dtype=np.float64)
    if np.array_equal(lower_values, upper_values, equal_nan=True):
        axis.plot(
            x,
            lower_values,
            color=line.get_color(),
            linewidth=8.0,
            alpha=0.10,
            solid_capstyle="round",
            zorder=1,
        )
        return True
    axis.fill_between(
        x,
        lower_values,
        upper_values,
        alpha=0.18,
        color=line.get_color(),
        zorder=1,
    )
    return False


def _annotate_reference_overlaps(
    axis: Any,
    plotted_series: Mapping[str, tuple[np.ndarray, np.ndarray]],
    reference_environment: str,
) -> list[str]:
    """Annotate candidates whose plotted curve is exactly identical to the reference."""

    reference = plotted_series.get(reference_environment)
    if reference is None:
        return []
    reference_x, reference_y = reference
    matches = []
    for name, (x, y) in plotted_series.items():
        if name == reference_environment:
            continue
        if (
            np.array_equal(x, reference_x, equal_nan=True)
            and np.array_equal(y, reference_y, equal_nan=True)
        ):
            matches.append(name)
    if matches:
        reference_label = _environment_label(reference_environment, reference_environment)
        axis.text(
            0.02,
            0.97,
            "Exact curve overlap\n" + reference_label + " = " + ", ".join(matches),
            transform=axis.transAxes,
            ha="left",
            va="top",
            fontsize=8.5,
            bbox={"boxstyle": "round,pad=0.35", "facecolor": "white", "alpha": 0.88},
            zorder=6,
        )
    return matches


def _preview_checkpoint_metrics(output: Mapping[str, Any]) -> dict[int, dict[str, float]]:
    preview = output.get("representative_preview")
    if not isinstance(preview, Mapping):
        return {}
    result: dict[int, dict[str, float]] = {}
    for step_name, metrics in preview.items():
        step = _step_number(str(step_name))
        if step is None or not isinstance(metrics, Mapping):
            continue
        values = {
            str(name): float(value)
            for name, value in metrics.items()
            if isinstance(value, (int, float)) and math.isfinite(float(value))
        }
        if values:
            result[step] = values
    return result


def _preview_final_logits(output: Mapping[str, Any]) -> Mapping[str, Any] | None:
    preview = output.get("representative_preview")
    if not isinstance(preview, Mapping):
        return None
    candidates = []
    for step_name, value in preview.items():
        step = _step_number(str(step_name))
        if step is not None and isinstance(value, Mapping):
            logits = value.get("logits") if isinstance(value.get("logits"), Mapping) else value
            candidates.append((step, logits))
    return max(candidates, default=(None, None), key=lambda item: -1 if item[0] is None else item[0])[1]


def _preview_samples(value: Mapping[str, Any]) -> tuple[np.ndarray, np.ndarray] | None:
    indices = value.get("sample_indices")
    samples = value.get("sample_values")
    if not isinstance(indices, list) or not isinstance(samples, list) or len(indices) != len(samples):
        return None
    try:
        return np.asarray(indices, dtype=np.int64), np.asarray(samples, dtype=np.float64)
    except (TypeError, ValueError):
        return None


def make_summary_model_plots(
    reference: Mapping[str, Any],
    candidates: Mapping[str, Mapping[str, Any]],
    output_directory: Path,
    policy: Mapping[str, Any],
) -> list[dict[str, Any]]:
    """Plot representative checkpoint metrics and sampled logits from analysis JSON."""

    try:
        import matplotlib.pyplot as plt
    except ImportError as exc:
        raise RuntimeError("Matplotlib is required unless --no-plots is used") from exc

    settings = reporting_settings(policy)
    analyses = {"reference": reference, **dict(candidates)}
    output_maps = {name: _output_map(analysis) for name, analysis in analyses.items()}
    details: list[dict[str, Any]] = []

    for loss_output_id in ("loss_series", "training_loss"):
        for reference_output in _model_outputs(reference, loss_output_id):
            key = str(reference_output.get("identity_key"))
            identity = reference_output.get("identity") or {}
            figure, axis = plt.subplots(figsize=(8.5, 5.2))
            plotted = False
            max_steps = max(1, int(settings.get("training_loss_step_count", 30)))
            plotted_series: dict[str, tuple[np.ndarray, np.ndarray]] = {}
            for name in _environment_plot_order(list(output_maps), "reference"):
                outputs = output_maps[name]
                output = outputs.get(key)
                preview = output.get("representative_preview") if isinstance(output, Mapping) else None
                if not isinstance(preview, list):
                    continue
                values = [
                    float(value)
                    for value in preview[:max_steps]
                    if isinstance(value, (int, float)) and math.isfinite(float(value))
                ]
                if not values:
                    continue
                start = 0 if loss_output_id == "loss_series" else 1
                x = np.arange(start, start + len(values))
                y = np.asarray(values, dtype=np.float64)
                _plot_environment_line(axis, x, y, name, "reference")
                plotted_series[name] = (x, y)
                plotted = True
            if plotted:
                overlaps = _annotate_reference_overlaps(axis, plotted_series, "reference")
                title = _plot_title(identity, "Training loss")
                caption = (
                    "Representative loss preview from each environment. Lower values indicate "
                    "better fit. Candidates use solid square-marked lines; the reference uses "
                    "a dashed line with hollow circular markers."
                )
                if overlaps:
                    caption += " The overlap note identifies curves with exactly equal plotted values."
                axis.set_xlabel("Optimisation step")
                axis.set_ylabel("Training loss")
                axis.legend(title="Environment")
                axis.grid(True, alpha=0.25)
                _finish_plot(figure, axis, title, caption)
                path = output_directory / _plot_filename("summary", identity, "training_loss")
                figure.savefig(path, dpi=160)
                details.append(
                    {
                        "path": path.name,
                        "kind": "training_step_loss",
                        "title": title,
                        "caption": caption,
                        "identity": identity,
                        "source": "repeatability_analysis_preview",
                    }
                )
            plt.close(figure)

    for reference_output in _model_outputs(reference, "checkpoint_metrics"):
        key = str(reference_output.get("identity_key"))
        identity = reference_output.get("identity") or {}
        series_by_environment = {
            name: _preview_checkpoint_metrics(outputs[key])
            for name, outputs in output_maps.items()
            if key in outputs
        }
        all_steps = sorted({step for series in series_by_environment.values() for step in series})
        steps = _selected_steps(all_steps, settings)
        for metric, y_label in (("loss", "Evaluation loss"), ("accuracy", "Evaluation accuracy")):
            figure, axis = plt.subplots(figsize=(8.5, 5.2))
            plotted = False
            plotted_series: dict[str, tuple[np.ndarray, np.ndarray]] = {}
            for name in _environment_plot_order(list(series_by_environment), "reference"):
                series = series_by_environment[name]
                x = [step for step in steps if metric in series.get(step, {})]
                y = [series[step][metric] for step in x]
                if not x:
                    continue
                x_values = np.asarray(x, dtype=np.float64)
                y_values = np.asarray(y, dtype=np.float64)
                _plot_environment_line(axis, x_values, y_values, name, "reference")
                plotted_series[name] = (x_values, y_values)
                plotted = True
            if not plotted:
                plt.close(figure)
                continue
            overlaps = _annotate_reference_overlaps(axis, plotted_series, "reference")
            title = _plot_title(identity, y_label)
            caption = (
                "Representative evaluation checkpoints from each environment. Candidates use "
                "solid square-marked lines; the reference uses a dashed line with hollow circles. "
                + (
                    "Higher is better; accuracy is shown as a percentage."
                    if metric == "accuracy"
                    else "Lower is better."
                )
            )
            if overlaps:
                caption += " The overlap note identifies curves with exactly equal plotted values."
            axis.set_xlabel("Optimisation step at evaluation checkpoint")
            axis.set_ylabel(y_label)
            if metric == "accuracy":
                from matplotlib.ticker import PercentFormatter

                axis.yaxis.set_major_formatter(PercentFormatter(xmax=1.0))
                axis.set_ylim(0.0, 1.0)
            axis.legend(title="Environment")
            axis.grid(True, alpha=0.25)
            _finish_plot(figure, axis, title, caption)
            path = output_directory / _plot_filename("summary", identity, metric)
            figure.savefig(path, dpi=160)
            plt.close(figure)
            details.append(
                {
                    "path": path.name,
                    "kind": f"training_{metric}",
                    "title": title,
                    "caption": caption,
                    "identity": identity,
                    "source": "repeatability_analysis_preview",
                }
            )

    for inference_output_id in ("evaluation_outputs", "checkpoint_logits"):
        for reference_output in _model_outputs(reference, inference_output_id):
            key = str(reference_output.get("identity_key"))
            identity = reference_output.get("identity") or {}
            reference_value = _preview_final_logits(reference_output)
            if reference_value is None:
                continue
            reference_samples = _preview_samples(reference_value)
            if reference_samples is None:
                continue
            reference_indices, reference_values = reference_samples
            figure, axis = plt.subplots(figsize=(6.8, 6.2))
            plotted = False
            all_values = [reference_values]
            for name, outputs in output_maps.items():
                if name == "reference" or key not in outputs:
                    continue
                candidate_value = _preview_final_logits(outputs[key])
                candidate_samples = _preview_samples(candidate_value or {})
                if candidate_samples is None:
                    continue
                candidate_indices, candidate_values = candidate_samples
                common, ref_positions, cand_positions = np.intersect1d(
                    reference_indices,
                    candidate_indices,
                    return_indices=True,
                )
                if common.size == 0:
                    continue
                maximum = max(1, int(settings.get("inference_preview_value_count", 512)))
                if common.size > maximum:
                    keep = np.linspace(0, common.size - 1, maximum, dtype=np.int64)
                    ref_positions = ref_positions[keep]
                    cand_positions = cand_positions[keep]
                left = reference_values[ref_positions]
                right = candidate_values[cand_positions]
                axis.scatter(left, right, s=12, alpha=0.55, label=name)
                all_values.append(right)
                plotted = True
            if not plotted:
                plt.close(figure)
                continue
            finite_parts = [values[np.isfinite(values)] for values in all_values]
            finite_parts = [values for values in finite_parts if values.size]
            finite_values = np.concatenate(finite_parts) if finite_parts else np.asarray([], dtype=np.float64)
            if finite_values.size:
                low, high = _shared_axis_limits(finite_values)
                axis.plot(
                    [low, high],
                    [low, high],
                    linestyle="--",
                    linewidth=1.2,
                    label="Exact agreement (y = x)",
                )
                axis.set_xlim(low, high)
                axis.set_ylim(low, high)
            title = _plot_title(identity, "Sampled final inference logits")
            caption = (
                "The reference is encoded on the x-axis. Candidate points on the dashed diagonal "
                "match the reference exactly; distance from the diagonal shows logit disagreement."
            )
            axis.set_xlabel("Reference sampled logit")
            axis.set_ylabel("Candidate sampled logit")
            axis.set_aspect("equal", adjustable="box")
            axis.legend(title="Candidate / baseline")
            axis.grid(True, alpha=0.25)
            _finish_plot(figure, axis, title, caption)
            path = output_directory / _plot_filename("summary", identity, "sampled_logits")
            figure.savefig(path, dpi=160)
            plt.close(figure)
            details.append(
                {
                    "path": path.name,
                    "kind": "inference_sampled_logits",
                    "title": title,
                    "caption": caption,
                    "identity": identity,
                    "source": "repeatability_analysis_preview",
                }
            )
    return details


def _find_run(runs: Sequence[RunBundle], run_id: str | None) -> RunBundle:
    if run_id is not None:
        for run in runs:
            if run.run_id == run_id:
                return run
    return sorted(runs, key=lambda item: item.run_id)[0]


def _scalar_from_descriptor(
    run: RunBundle,
    descriptor: Mapping[str, Any],
    *,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> float:
    values = load_tensor(
        run,
        descriptor,
        verify_hash=verify_hash,
        verified_paths=verified_paths,
    )
    if values.size != 1:
        raise RuntimeError("Expected one scalar tensor in checkpoint_metrics")
    return float(np.asarray(values).reshape(-1)[0])


def _raw_training_loss(run: RunBundle, identity_key: str) -> np.ndarray | None:
    record = run.observations.get(identity_key)
    if not isinstance(record, Mapping) or record.get("status") != "produced":
        return None
    payload = record.get("payload")
    if not isinstance(payload, list):
        return None
    try:
        values = np.asarray(payload, dtype=np.float64)
    except (TypeError, ValueError):
        return None
    return values if values.ndim == 1 else None


def _raw_checkpoint_metrics(
    run: RunBundle,
    identity_key: str,
    *,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> dict[int, dict[str, float]]:
    record = run.observations.get(identity_key)
    if not isinstance(record, Mapping) or record.get("status") != "produced":
        return {}
    payload = record.get("payload")
    if not isinstance(payload, Mapping):
        return {}
    result: dict[int, dict[str, float]] = {}
    for step_name, metrics in payload.items():
        step = _step_number(str(step_name))
        if step is None or not isinstance(metrics, Mapping):
            continue
        values = {}
        for metric in ("loss", "accuracy"):
            descriptor = metrics.get(metric)
            if isinstance(descriptor, Mapping) and descriptor.get("artifact_type") == "tensor":
                values[metric] = _scalar_from_descriptor(
                    run,
                    descriptor,
                    verify_hash=verify_hash,
                    verified_paths=verified_paths,
                )
        if values:
            result[step] = values
    return result


def _raw_final_logits(
    run: RunBundle,
    identity_key: str,
    *,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> tuple[int, np.ndarray] | None:
    record = run.observations.get(identity_key)
    if not isinstance(record, Mapping) or record.get("status") != "produced":
        return None
    payload = record.get("payload")
    if not isinstance(payload, Mapping):
        return None
    candidates = []
    for step_name, descriptor in payload.items():
        step = _step_number(str(step_name))
        if step is None or not isinstance(descriptor, Mapping):
            continue
        candidate = descriptor.get("logits") if isinstance(descriptor.get("logits"), Mapping) else descriptor
        if candidate.get("artifact_type") == "tensor":
            candidates.append((step, candidate))
    if not candidates:
        return None
    step, descriptor = max(candidates, key=lambda item: item[0])
    return step, load_tensor(
        run,
        descriptor,
        verify_hash=verify_hash,
        verified_paths=verified_paths,
    )


def _common_run_metric_envelope(
    runs: Sequence[RunBundle],
    identity_key: str,
    metric: str,
    steps: Sequence[int],
    *,
    verify_hash: bool,
    verified_paths: set[tuple[str, str]],
) -> tuple[np.ndarray, np.ndarray] | None:
    rows = []
    for run in runs:
        series = _raw_checkpoint_metrics(
            run,
            identity_key,
            verify_hash=verify_hash,
            verified_paths=verified_paths,
        )
        if all(metric in series.get(step, {}) for step in steps):
            rows.append([series[step][metric] for step in steps])
    if not rows:
        return None
    values = np.asarray(rows, dtype=np.float64)
    return np.min(values, axis=0), np.max(values, axis=0)


def make_detailed_model_plots(
    runs_by_environment: Mapping[str, Sequence[RunBundle]],
    analyses: Mapping[str, Mapping[str, Any]],
    reference_environment: str,
    output_directory: Path,
    policy: Mapping[str, Any],
    *,
    verify_hash: bool,
) -> list[dict[str, Any]]:
    """Plot raw checkpoint metrics and final logits from representative runs."""

    try:
        import matplotlib.pyplot as plt
    except ImportError as exc:
        raise RuntimeError("Matplotlib is required unless --no-plots is used") from exc

    settings = reporting_settings(policy)
    reference_analysis = analyses[reference_environment]
    output_maps = {name: _output_map(analysis) for name, analysis in analyses.items()}
    representative_runs = {
        name: _find_run(runs_by_environment[name], analysis.get("environment_representative_run"))
        for name, analysis in analyses.items()
    }
    verified_paths: set[tuple[str, str]] = set()
    details: list[dict[str, Any]] = []

    for loss_output_id in ("loss_series", "training_loss"):
        for reference_output in _model_outputs(reference_analysis, loss_output_id):
            key = str(reference_output.get("identity_key"))
            identity = reference_output.get("identity") or {}
            max_steps = max(1, int(settings.get("training_loss_step_count", 30)))
            figure, axis = plt.subplots(figsize=(8.5, 5.2))
            plotted = False
            plotted_series: dict[str, tuple[np.ndarray, np.ndarray]] = {}
            collapsed_bands: list[str] = []
            for name in _environment_plot_order(list(output_maps), reference_environment):
                outputs = output_maps[name]
                if key not in outputs:
                    continue
                representative = _raw_training_loss(representative_runs[name], key)
                if representative is None or representative.size == 0:
                    continue
                count = min(representative.size, max_steps)
                start = 0 if loss_output_id == "loss_series" else 1
                x = np.arange(start, start + count)
                y = np.asarray(representative[:count], dtype=np.float64)
                line = _plot_environment_line(axis, x, y, name, reference_environment)
                plotted_series[name] = (x.astype(np.float64), y)
                all_runs = [
                    values[:count]
                    for run in runs_by_environment[name]
                    if (values := _raw_training_loss(run, key)) is not None and values.size >= count
                ]
                if len(all_runs) > 1:
                    stacked = np.asarray(all_runs, dtype=np.float64)
                    if _draw_repeatability_envelope(
                        axis,
                        x,
                        np.min(stacked, axis=0),
                        np.max(stacked, axis=0),
                        line,
                    ):
                        collapsed_bands.append(name)
                plotted = True
            if plotted:
                overlaps = _annotate_reference_overlaps(
                    axis, plotted_series, reference_environment
                )
                title = _plot_title(identity, "Training loss")
                caption = (
                    "Each line is the representative run for an environment. Candidates use solid "
                    "square-marked lines; the reference is drawn last as a dashed line with hollow "
                    "circles, so exactly coincident curves remain visible. Shaded bands show the "
                    "minimum-to-maximum range across repeat runs; lower loss is better."
                )
                if collapsed_bands:
                    caption += (
                        " For " + ", ".join(collapsed_bands)
                        + ", all plotted repeats are identical, so the zero-width band is shown "
                        "as a faint halo around the line."
                    )
                if overlaps:
                    caption += " The in-plot overlap note confirms exact equality at every plotted step."
                axis.set_xlabel("Optimisation step")
                axis.set_ylabel("Training loss")
                axis.legend(title="Environment")
                axis.grid(True, alpha=0.25)
                _finish_plot(figure, axis, title, caption)
                path = output_directory / _plot_filename("detailed", identity, "training_loss")
                figure.savefig(path, dpi=160)
                details.append(
                    {
                        "path": path.name,
                        "kind": "training_step_loss",
                        "title": title,
                        "caption": caption,
                        "identity": identity,
                        "source": "raw_representative_runs_with_repeatability_envelope",
                    }
                )
            plt.close(figure)

    for reference_output in _model_outputs(reference_analysis, "checkpoint_metrics"):
        key = str(reference_output.get("identity_key"))
        identity = reference_output.get("identity") or {}
        representative_series = {
            name: _raw_checkpoint_metrics(
                representative_runs[name],
                key,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
            )
            for name, outputs in output_maps.items()
            if key in outputs
        }
        all_steps = sorted({step for series in representative_series.values() for step in series})
        steps = _selected_steps(all_steps, settings)
        for metric, y_label in (("loss", "Evaluation loss"), ("accuracy", "Evaluation accuracy")):
            figure, axis = plt.subplots(figsize=(8.5, 5.2))
            plotted = False
            plotted_series: dict[str, tuple[np.ndarray, np.ndarray]] = {}
            collapsed_bands: list[str] = []
            for name in _environment_plot_order(list(representative_series), reference_environment):
                series = representative_series[name]
                x = [step for step in steps if metric in series.get(step, {})]
                y = [series[step][metric] for step in x]
                if not x:
                    continue
                x_values = np.asarray(x, dtype=np.float64)
                y_values = np.asarray(y, dtype=np.float64)
                line = _plot_environment_line(
                    axis, x_values, y_values, name, reference_environment
                )
                plotted_series[name] = (x_values, y_values)
                envelope = _common_run_metric_envelope(
                    runs_by_environment[name],
                    key,
                    metric,
                    x,
                    verify_hash=verify_hash,
                    verified_paths=verified_paths,
                )
                if envelope is not None and len(runs_by_environment[name]) > 1:
                    lower, upper = envelope
                    if _draw_repeatability_envelope(axis, x_values, lower, upper, line):
                        collapsed_bands.append(name)
                plotted = True
            if not plotted:
                plt.close(figure)
                continue
            overlaps = _annotate_reference_overlaps(
                axis, plotted_series, reference_environment
            )
            title = _plot_title(identity, y_label)
            caption = (
                "Each line is the representative run for an environment. Candidates use solid "
                "square-marked lines; the reference uses a dashed line with hollow circles. "
                "Shaded bands show the minimum-to-maximum range across repeat runs. "
                + (
                    "Higher is better; accuracy is shown as a percentage."
                    if metric == "accuracy"
                    else "Lower is better."
                )
            )
            if collapsed_bands:
                caption += (
                    " For " + ", ".join(collapsed_bands)
                    + ", the repeat-run range is exactly zero and is shown as a faint halo."
                )
            if overlaps:
                caption += " The in-plot overlap note confirms exact equality at every checkpoint."
            axis.set_xlabel("Optimisation step at evaluation checkpoint")
            axis.set_ylabel(y_label)
            if metric == "accuracy":
                from matplotlib.ticker import PercentFormatter

                axis.yaxis.set_major_formatter(PercentFormatter(xmax=1.0))
                axis.set_ylim(0.0, 1.0)
            axis.legend(title="Environment")
            axis.grid(True, alpha=0.25)
            _finish_plot(figure, axis, title, caption)
            path = output_directory / _plot_filename("detailed", identity, metric)
            figure.savefig(path, dpi=160)
            plt.close(figure)
            details.append(
                {
                    "path": path.name,
                    "kind": f"training_{metric}",
                    "title": title,
                    "caption": caption,
                    "identity": identity,
                    "source": "raw_representative_runs_with_repeatability_envelope",
                }
            )

    for inference_output_id in ("evaluation_outputs", "checkpoint_logits"):
        for reference_output in _model_outputs(reference_analysis, inference_output_id):
            key = str(reference_output.get("identity_key"))
            identity = reference_output.get("identity") or {}
            reference_result = _raw_final_logits(
                representative_runs[reference_environment],
                key,
                verify_hash=verify_hash,
                verified_paths=verified_paths,
            )
            if reference_result is None:
                continue
            reference_step, reference_logits = reference_result
            candidate_logits = {}
            for name, outputs in output_maps.items():
                if name == reference_environment or key not in outputs:
                    continue
                result = _raw_final_logits(
                    representative_runs[name],
                    key,
                    verify_hash=verify_hash,
                    verified_paths=verified_paths,
                )
                if result is None or result[0] != reference_step or result[1].shape != reference_logits.shape:
                    continue
                candidate_logits[name] = result[1]
            if not candidate_logits:
                continue

            flat_reference = np.asarray(reference_logits).reshape(-1).astype(np.float64)
            point_count = min(
                flat_reference.size,
                max(1, int(settings.get("inference_scatter_point_count", 2_000))),
            )
            indices = np.linspace(0, flat_reference.size - 1, point_count, dtype=np.int64)
            figure, axis = plt.subplots(figsize=(6.8, 6.2))
            all_values = [flat_reference[indices]]
            for name, logits in candidate_logits.items():
                values = np.asarray(logits).reshape(-1).astype(np.float64)[indices]
                axis.scatter(flat_reference[indices], values, s=10, alpha=0.5, label=name)
                all_values.append(values)
            finite_parts = [values[np.isfinite(values)] for values in all_values]
            finite_parts = [values for values in finite_parts if values.size]
            finite_values = np.concatenate(finite_parts) if finite_parts else np.asarray([], dtype=np.float64)
            if finite_values.size:
                low, high = _shared_axis_limits(finite_values)
                axis.plot(
                    [low, high],
                    [low, high],
                    linestyle="--",
                    linewidth=1.2,
                    label="Exact agreement (y = x)",
                )
                axis.set_xlim(low, high)
                axis.set_ylim(low, high)
            title = _plot_title(identity, f"Final inference logits at step {reference_step}")
            caption = (
                f"The {reference_environment} representative run is encoded on the x-axis. "
                "Candidate points on the dashed diagonal match it exactly; distance from the "
                "diagonal shows logit disagreement."
            )
            axis.set_xlabel(_reference_axis_label(reference_environment))
            axis.set_ylabel("Candidate final logit")
            axis.set_aspect("equal", adjustable="box")
            axis.legend(title="Candidate / baseline")
            axis.grid(True, alpha=0.25)
            _finish_plot(figure, axis, title, caption)
            scatter_path = output_directory / _plot_filename("detailed", identity, "final_logits_scatter")
            figure.savefig(scatter_path, dpi=160)
            plt.close(figure)
            details.append(
                {
                    "path": scatter_path.name,
                    "kind": "inference_logits_scatter",
                    "title": title,
                    "caption": caption,
                    "identity": identity,
                    "source": "raw_representative_runs",
                }
            )

            sample_errors: dict[str, np.ndarray] = {}
            reference_array = np.asarray(reference_logits, dtype=np.float64)
            for name, logits in candidate_logits.items():
                difference = np.abs(np.asarray(logits, dtype=np.float64) - reference_array)
                if difference.ndim >= 2:
                    errors = np.max(difference.reshape(difference.shape[0], -1), axis=1)
                else:
                    errors = difference.reshape(-1)
                sample_errors[name] = errors
            max_samples = max(1, int(settings.get("inference_sample_error_count", 256)))
            figure, axis = plt.subplots(figsize=(9, 5.2))
            axis.axhline(
                0.0,
                linestyle="--",
                linewidth=1.2,
                label=f"{reference_environment} baseline (zero error)",
            )
            for name, errors in sample_errors.items():
                count = min(errors.size, max_samples)
                sample_indices = np.linspace(0, errors.size - 1, count, dtype=np.int64)
                axis.plot(sample_indices, errors[sample_indices], label=name)
            title = _plot_title(identity, "Per-sample final inference error")
            caption = (
                f"Each candidate curve is |candidate − {reference_environment}| for the largest "
                "logit error in each sampled evaluation item. The dashed zero line is the "
                "reference self-comparison baseline; lower is better."
            )
            axis.set_xlabel("Evaluation sample index")
            axis.set_ylabel(f"Maximum absolute logit error from {reference_environment}")
            axis.set_ylim(bottom=0.0)
            axis.legend(title="Environment / baseline")
            axis.grid(True, alpha=0.25)
            _finish_plot(figure, axis, title, caption)
            error_path = output_directory / _plot_filename("detailed", identity, "final_logits_error")
            figure.savefig(error_path, dpi=160)
            plt.close(figure)
            details.append(
                {
                    "path": error_path.name,
                    "kind": "inference_per_sample_error",
                    "title": title,
                    "caption": caption,
                    "identity": identity,
                    "source": "raw_representative_runs",
                }
            )

            if reference_array.ndim >= 2 and reference_array.shape[-1] > 1:
                reference_predictions = np.argmax(reference_array, axis=-1).reshape(-1)
                names = [_environment_label(reference_environment, reference_environment)]
                disagreement_fractions = [0.0]
                for name, logits in candidate_logits.items():
                    predictions = np.argmax(np.asarray(logits), axis=-1).reshape(-1)
                    names.append(name)
                    disagreement_fractions.append(
                        float(np.mean(predictions != reference_predictions))
                    )
                figure, axis = plt.subplots(figsize=(max(7, len(names) * 1.3), 4.8))
                positions = np.arange(len(names))
                bars = axis.bar(positions, disagreement_fractions)
                axis.bar_label(
                    bars,
                    labels=[f"{value:.2%}" for value in disagreement_fractions],
                    padding=3,
                    fontsize=8,
                )
                title = _plot_title(identity, "Final prediction disagreements")
                caption = (
                    f"Fraction of evaluation items whose predicted class differs from the "
                    f"{reference_environment} representative run. The reference self-comparison "
                    "is included explicitly at 0%; lower is better."
                )
                axis.set_xticks(positions)
                axis.set_xticklabels(names, rotation=35, ha="right")
                axis.set_ylabel(f"Prediction disagreement from {reference_environment}")
                from matplotlib.ticker import PercentFormatter

                axis.yaxis.set_major_formatter(PercentFormatter(xmax=1.0))
                maximum_disagreement = max(disagreement_fractions, default=0.0)
                axis.set_ylim(0.0, max(0.01, min(1.0, maximum_disagreement * 1.25 + 0.005)))
                axis.axhline(0.0, linestyle="--", linewidth=1.0)
                axis.grid(True, axis="y", alpha=0.25)
                _finish_plot(figure, axis, title, caption)
                disagreement_path = output_directory / _plot_filename(
                    "detailed", identity, "prediction_disagreements"
                )
                figure.savefig(disagreement_path, dpi=160)
                plt.close(figure)
                details.append(
                    {
                        "path": disagreement_path.name,
                        "kind": "inference_prediction_disagreement",
                        "title": title,
                        "caption": caption,
                        "identity": identity,
                        "source": "raw_representative_runs",
                    }
                )
    return details
