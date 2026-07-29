"""Configuration package for pytorch_extended_tests."""

from .suite_config import (
    CONFIG_VERSION,
    RESULT_FORMAT_VERSION,
    ROOT_SEED,
    SUITE_NAME,
    SUITE_VERSION,
    TEST_CATALOGUE_VERSION,
    derive_seed,
)

__all__ = [
    "CONFIG_VERSION",
    "RESULT_FORMAT_VERSION",
    "ROOT_SEED",
    "SUITE_NAME",
    "SUITE_VERSION",
    "TEST_CATALOGUE_VERSION",
    "derive_seed",
]
