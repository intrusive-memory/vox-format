"""Tests for VoxValidator.

Tests verify that VoxValidator correctly validates .vox manifests, rejects invalid
fields, and handles both permissive and strict validation modes.
"""

import pytest
from pathlib import Path

from voxformat.validator import VoxValidator
from voxformat.reader import VoxReader
from voxformat.errors import (
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
from voxformat import VoxManifest, Voice, ReferenceAudio


# Path to examples directory (relative to project root)
EXAMPLES_DIR = Path(__file__).parent.parent.parent.parent / "examples"


class TestValidatorValidExamples:
    """Test validation of all example .vox files."""

    def test_validates_minimal_example(self):
        """Test that minimal narrator.vox validates successfully."""
        reader = VoxReader()
        validator = VoxValidator()
        vox_path = EXAMPLES_DIR / "minimal" / "narrator.vox"

        vox_file = reader.read(vox_path)
        # Should not raise any exception
        validator.validate(vox_file.manifest)

    def test_validates_multi_engine_example(self):
        """Test that cross-platform.vox validates successfully."""
        reader = VoxReader()
        validator = VoxValidator()
        vox_path = EXAMPLES_DIR / "multi-engine" / "cross-platform.vox"

        vox_file = reader.read(vox_path)
        # Should not raise any exception
        validator.validate(vox_file.manifest)

    def test_validates_character_context_example(self):
        """Test that narrator-with-context.vox validates successfully."""
        reader = VoxReader()
        validator = VoxValidator()
        vox_path = EXAMPLES_DIR / "character" / "narrator-with-context.vox"

        vox_file = reader.read(vox_path)
        # Should not raise any exception
        validator.validate(vox_file.manifest)


class TestRequiredFieldsValidation:
    """Test validation of required manifest fields."""

    def test_rejects_missing_vox_version(self):
        """Test that validator rejects empty vox_version."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="",  # Empty string
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="Test", description="Test description here")
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, EmptyRequiredField) and e.field == "vox_version" for e in errors)

    def test_rejects_invalid_uuid(self):
        """Test that validator rejects malformed UUID."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="not-a-valid-uuid",  # Invalid UUID
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="Test", description="Test description here")
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, InvalidUUID) and e.field == "id" for e in errors)

    def test_rejects_invalid_timestamp(self):
        """Test that validator rejects malformed ISO 8601 timestamp."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15 10:30:00",  # Missing T separator and Z
            voice=Voice(name="Test", description="Test description here")
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, InvalidTimestamp) and e.field == "created" for e in errors)

    def test_rejects_empty_voice_name(self):
        """Test that validator rejects empty voice.name."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="", description="Test description here")  # Empty name
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, EmptyRequiredField) and e.field == "voice.name" for e in errors)

    def test_rejects_empty_voice_description(self):
        """Test that validator rejects empty voice.description."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="Test", description="")  # Empty description
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, EmptyRequiredField) and e.field == "voice.description" for e in errors)

    def test_rejects_short_voice_description(self):
        """Test that validator rejects voice.description under 10 characters."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="Test", description="Short")  # Only 5 chars
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, DescriptionTooShort) and e.field == "voice.description" for e in errors)


class TestOptionalFieldsValidation:
    """Test validation of optional manifest fields."""

    def test_rejects_invalid_age_range_min_greater_than_max(self):
        """Test that validator rejects age_range where min >= max."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(
                name="Test",
                description="Test description here",
                age_range=[30, 20]  # min > max
            )
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, InvalidAgeRange) for e in errors)

    def test_rejects_invalid_age_range_equal_values(self):
        """Test that validator rejects age_range where min == max."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(
                name="Test",
                description="Test description here",
                age_range=[25, 25]  # min == max
            )
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, InvalidAgeRange) for e in errors)

    def test_accepts_valid_age_range(self):
        """Test that validator accepts valid age_range."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(
                name="Test",
                description="Test description here",
                age_range=[25, 35]  # valid range
            )
        )

        # Should not raise
        validator.validate(manifest)

    def test_rejects_invalid_gender(self):
        """Test that validator rejects invalid gender enum value."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(
                name="Test",
                description="Test description here",
                gender="unknown"  # Not in allowed enum
            )
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, InvalidGender) for e in errors)

    def test_accepts_valid_genders(self):
        """Test that validator accepts all valid gender enum values."""
        validator = VoxValidator()
        valid_genders = ["male", "female", "non-binary", "neutral"]

        for gender in valid_genders:
            manifest = VoxManifest(
                vox_version="0.1.0",
                id="550e8400-e29b-41d4-a716-446655440000",
                created="2025-01-15T10:30:00Z",
                voice=Voice(
                    name="Test",
                    description="Test description here",
                    gender=gender
                )
            )
            # Should not raise
            validator.validate(manifest)

    def test_rejects_empty_reference_audio_file_path(self):
        """Test that validator rejects reference_audio with empty file path."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="Test", description="Test description here"),
            reference_audio=[
                ReferenceAudio(file="", transcript="Some text")  # Empty file path
            ]
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, EmptyReferenceAudioPath) for e in errors)

    def test_accepts_valid_reference_audio(self):
        """Test that validator accepts reference_audio with non-empty file path."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="Test", description="Test description here"),
            reference_audio=[
                ReferenceAudio(file="reference/sample.wav", transcript="Some text")
            ]
        )

        # Should not raise
        validator.validate(manifest)


class TestStrictMode:
    """Test strict validation mode behavior."""

    def test_strict_mode_raises_first_error_only(self):
        """Test that strict mode raises immediately on first error."""
        validator = VoxValidator()
        # Create manifest with multiple errors
        manifest = VoxManifest(
            vox_version="",  # Error 1: empty
            id="invalid-uuid",  # Error 2: invalid UUID
            created="invalid-timestamp",  # Error 3: invalid timestamp
            voice=Voice(name="", description="")  # Error 4 & 5: empty name and description
        )

        with pytest.raises(ValidationError) as exc_info:
            validator.validate(manifest, strict=True)

        # In strict mode, should raise single ValidationError (not MultipleValidationErrors)
        assert not isinstance(exc_info.value, MultipleValidationErrors)
        # Should be one of the specific error types
        assert isinstance(exc_info.value, (EmptyRequiredField, InvalidUUID, InvalidTimestamp))

    def test_permissive_mode_collects_all_errors(self):
        """Test that permissive mode collects all errors."""
        validator = VoxValidator()
        # Create manifest with multiple errors
        manifest = VoxManifest(
            vox_version="",  # Error 1
            id="invalid-uuid",  # Error 2
            created="invalid-timestamp",  # Error 3
            voice=Voice(name="", description="")  # Error 4 & 5
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest, strict=False)

        # Should collect all errors
        errors = exc_info.value.errors
        assert len(errors) >= 4  # At least 4 distinct errors


class TestEdgeCases:
    """Test edge cases and boundary conditions."""

    def test_whitespace_only_fields_are_rejected(self):
        """Test that fields with only whitespace are treated as empty."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="   ",  # Only whitespace
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="Test", description="Test description here")
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, EmptyRequiredField) and e.field == "vox_version" for e in errors)

    def test_uuid_case_insensitive_validation(self):
        """Test that UUID validation is case-insensitive."""
        validator = VoxValidator()
        # Both uppercase and lowercase should be valid
        uuids = [
            "550e8400-e29b-41d4-a716-446655440000",  # lowercase
            "550E8400-E29B-41D4-A716-446655440000",  # uppercase
            "550e8400-E29B-41d4-A716-446655440000",  # mixed
        ]

        for uuid_value in uuids:
            manifest = VoxManifest(
                vox_version="0.1.0",
                id=uuid_value,
                created="2025-01-15T10:30:00Z",
                voice=Voice(name="Test", description="Test description here")
            )
            # Should not raise
            validator.validate(manifest)

    def test_description_exactly_minimum_length(self):
        """Test that description with exactly minimum length (10 chars) is valid."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="Test", description="1234567890")  # Exactly 10 chars
        )

        # Should not raise
        validator.validate(manifest)

    def test_description_one_char_below_minimum(self):
        """Test that description with 9 characters is rejected."""
        validator = VoxValidator()
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="550e8400-e29b-41d4-a716-446655440000",
            created="2025-01-15T10:30:00Z",
            voice=Voice(name="Test", description="123456789")  # Only 9 chars
        )

        with pytest.raises(MultipleValidationErrors) as exc_info:
            validator.validate(manifest)

        errors = exc_info.value.errors
        assert any(isinstance(e, DescriptionTooShort) for e in errors)
