"""FFT cases which retain both transforms and inverse reconstructions."""

from __future__ import annotations

from collections.abc import Callable

from cases.common import as_profile_tensor, load_prepared_npz, run_registered_case
from pytorch_extended_tests.case_api import CaseContext, ObservationRecorder

DATASET_ID = "numerical_inputs_v1"


def _inputs(context: CaseContext) -> dict[str, object]:
    arrays = load_prepared_npz(context, DATASET_ID, "fft.npz")
    return {
        name: as_profile_tensor(context, value)
        for name, value in arrays.items()
    }


def _record(
    recorder: ObservationRecorder,
    *,
    transforms: dict[str, object],
    reconstructions: dict[str, object],
) -> None:
    recorder.record("transforms", transforms)
    recorder.record("reconstructions", reconstructions)


def _fft_1d(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    source = _inputs(context)["complex_1d"]
    transform = torch.fft.fft(source)
    orthonormal_transform = torch.fft.fft(source, norm="ortho")
    _record(
        recorder,
        transforms={"default": transform, "orthonormal": orthonormal_transform},
        reconstructions={
            "default": torch.fft.ifft(transform),
            "orthonormal": torch.fft.ifft(orthonormal_transform, norm="ortho"),
        },
    )


def _fft_2d(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    source = _inputs(context)["complex_2d"]
    transform = torch.fft.fft2(source)
    shifted = torch.fft.fftshift(transform)
    _record(
        recorder,
        transforms={"default": transform, "shifted": shifted},
        reconstructions={
            "default": torch.fft.ifft2(transform),
            "shifted": torch.fft.ifft2(torch.fft.ifftshift(shifted)),
        },
    )


def _real_fft(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    source_1d = _inputs(context)["real_1d"]
    source_2d = _inputs(context)["real_2d"]
    transform_1d = torch.fft.rfft(source_1d)
    transform_2d = torch.fft.rfft2(source_2d)
    _record(
        recorder,
        transforms={"one_dimensional": transform_1d, "two_dimensional": transform_2d},
        reconstructions={
            "one_dimensional": torch.fft.irfft(transform_1d, n=source_1d.shape[0]),
            "two_dimensional": torch.fft.irfft2(transform_2d, s=source_2d.shape),
        },
    )


def _inverse_round_trip(context: CaseContext, recorder: ObservationRecorder) -> None:
    import torch

    source = _inputs(context)["complex_2d"]
    inverse_transform = torch.fft.ifftn(source)
    _record(
        recorder,
        transforms={"inverse": inverse_transform},
        reconstructions={"forward_after_inverse": torch.fft.fftn(inverse_transform)},
    )


_CASES: dict[str, Callable[[CaseContext, ObservationRecorder], None]] = {
    "fft_1d": _fft_1d,
    "fft_2d": _fft_2d,
    "real_fft": _real_fft,
    "inverse_round_trip": _inverse_round_trip,
}


def run_case(context: CaseContext, recorder: ObservationRecorder) -> None:
    """Run one FFT case selected by the catalogue."""

    run_registered_case(context, recorder, _CASES)
