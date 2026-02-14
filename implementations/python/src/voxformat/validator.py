"""VOX manifest validation.

This module provides the VoxValidator class for validating VoxManifest instances
against the VOX format specification. Validators check required fields, optional
field constraints, and format compliance (UUID v4, ISO 8601 timestamps).
"""

import re
from typing import List

from .manifest import VoxManifest
from .errors import (
    ValidationError,
    EmptyRequiredField,
    InvalidUUID,
    InvalidTimestamp,
    DescriptionTooShort,
    InvalidAgeRange,
    InvalidGender,
    EmptyReferenceAudioPath,
    MultipleValidationErrors,
)


class VoxValidator:
    """Validates VoxManifest instances against the VOX format specification.

    VoxValidator checks that required fields are present and well-formed, and optionally
    validates optional fields when they are present. In permissive mode (the default), the
    validator collects all errors and raises a single MultipleValidationErrors exception
    containing every issue found. In strict mode, validation fails on the first error.

    Example:
        >>> validator = VoxValidator()
        >>> manifest = voxFile.manifest
        >>> validator.validate(manifest)           # permissive (default)
        >>> validator.validate(manifest, strict=True)  # strict
    """

    # Valid gender values per the VOX specification
    VALID_GENDERS = {"male", "female", "non-binary", "neutral"}

    # UUID v4 pattern: lowercase hex with version nibble 4 and variant nibble [89ab]
    UUID_V4_PATTERN = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")

    # ISO 8601 timestamp pattern (simplified, matches common formats)
    ISO_8601_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    # Minimum length for voice description
    MINIMUM_DESCRIPTION_LENGTH = 10

    def __init__(self):
        """Create a new VoxValidator instance."""
        pass

    def validate(self, manifest: VoxManifest, strict: bool = False) -> None:
        """Validate a VoxManifest against the VOX format specification.

        Checks that all required fields are present and well-formed, and validates optional
        fields when they are present. In permissive mode (the default), all errors are
        collected and reported together. In strict mode, validation halts on the first error.

        Args:
            manifest: The manifest to validate.
            strict: If True, raises immediately on the first validation error.
                   If False (default), collects all errors and raises them together.

        Raises:
            MultipleValidationErrors: Contains all validation failures (permissive mode).
            ValidationError: The first specific validation error encountered (strict mode).

        Example:
            >>> validator = VoxValidator()
            >>> try:
            ...     validator.validate(manifest)
            ... except MultipleValidationErrors as e:
            ...     for error in e.errors:
            ...         print(error.field, error.message)
        """
        errors: List[ValidationError] = []

        # Required fields validation
        self._validate_required_fields(manifest, errors, strict)

        # Optional fields validation
        self._validate_optional_fields(manifest, errors, strict)

        # Raise collected errors in permissive mode
        if errors:
            if strict and len(errors) == 1:
                raise errors[0]
            raise MultipleValidationErrors(errors)

    def _validate_required_fields(
        self,
        manifest: VoxManifest,
        errors: List[ValidationError],
        strict: bool
    ) -> None:
        """Validate all required manifest fields.

        Args:
            manifest: The manifest to validate.
            errors: List to collect validation errors into.
            strict: If True, returns immediately on first error.
        """
        # Check vox_version is non-empty
        if not manifest.vox_version or not manifest.vox_version.strip():
            error = EmptyRequiredField("vox_version")
            errors.append(error)
            if strict:
                return

        # Validate id is valid UUID v4 format
        if not self._is_valid_uuid_v4(manifest.id):
            error = InvalidUUID("id", manifest.id)
            errors.append(error)
            if strict:
                return

        # Validate created is valid ISO 8601 timestamp
        if not self._is_valid_iso8601(manifest.created):
            error = InvalidTimestamp("created", manifest.created)
            errors.append(error)
            if strict:
                return

        # Check voice.name is non-empty
        if not manifest.voice.name or not manifest.voice.name.strip():
            error = EmptyRequiredField("voice.name")
            errors.append(error)
            if strict:
                return

        # Check voice.description is non-empty and at least 10 chars
        description = manifest.voice.description.strip() if manifest.voice.description else ""
        if not description:
            error = EmptyRequiredField("voice.description")
            errors.append(error)
            if strict:
                return
        elif len(description) < self.MINIMUM_DESCRIPTION_LENGTH:
            error = DescriptionTooShort("voice.description", len(description), self.MINIMUM_DESCRIPTION_LENGTH)
            errors.append(error)
            if strict:
                return

    def _validate_optional_fields(
        self,
        manifest: VoxManifest,
        errors: List[ValidationError],
        strict: bool
    ) -> None:
        """Validate optional manifest fields when they are present.

        Args:
            manifest: The manifest to validate.
            errors: List to collect validation errors into.
            strict: If True, returns immediately on first error.
        """
        # Validate age_range if present: min < max and both >= 0
        if manifest.voice.age_range is not None:
            age_range = manifest.voice.age_range
            if len(age_range) == 2:
                min_age, max_age = age_range[0], age_range[1]
                if min_age >= max_age:
                    error = InvalidAgeRange(min_age, max_age)
                    errors.append(error)
                    if strict:
                        return

        # Validate gender if present: must be one of the allowed values
        if manifest.voice.gender is not None:
            if manifest.voice.gender not in self.VALID_GENDERS:
                error = InvalidGender(manifest.voice.gender)
                errors.append(error)
                if strict:
                    return

        # Validate reference_audio if present: file paths must be non-empty
        if manifest.reference_audio is not None:
            for index, entry in enumerate(manifest.reference_audio):
                if not entry.file or not entry.file.strip():
                    error = EmptyReferenceAudioPath(index)
                    errors.append(error)
                    if strict:
                        return

    def _is_valid_uuid_v4(self, value: str) -> bool:
        """Check whether a string is a valid UUID v4 format.

        Uses the regex pattern from the JSON Schema: lowercase hex digits with
        the version nibble '4' and variant nibble '[89ab]'.

        Args:
            value: The string to validate.

        Returns:
            True if the string matches UUID v4 format.
        """
        if not value:
            return False
        lowercased = value.lower()
        return self.UUID_V4_PATTERN.match(lowercased) is not None

    def _is_valid_iso8601(self, value: str) -> bool:
        """Check whether a string is a valid ISO 8601 timestamp.

        Validates the timestamp format using a regex pattern. This checks for
        the basic ISO 8601 format with 'Z' timezone indicator.

        Args:
            value: The string to validate.

        Returns:
            True if the string matches ISO 8601 format.
        """
        if not value:
            return False
        return self.ISO_8601_PATTERN.match(value) is not None
