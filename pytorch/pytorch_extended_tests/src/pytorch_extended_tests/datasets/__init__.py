"""Prepared dataset validation used before the suite starts."""

from .validation import DatasetValidationError, validate_datasets

__all__ = ["DatasetValidationError", "validate_datasets"]
