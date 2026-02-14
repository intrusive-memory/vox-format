"""VOX Format Python Library.

A Python library for reading, writing, and validating VOX voice identity files.
VOX is an open, vendor-neutral file format for voice identities used in text-to-speech synthesis.
"""

__version__ = "0.1.0"

from .manifest import (
    VoxManifest,
    Voice,
    Prosody,
    ReferenceAudio,
    Character,
    Source,
    Provenance,
)
from .vox_file import VoxFile
from .reader import VoxReader
from .writer import VoxWriter
from .validator import VoxValidator
from .errors import (
    VoxError,
    InvalidArchive,
    ManifestNotFound,
    InvalidManifest,
    InvalidReferenceAudio,
    WriteError,
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

__all__ = [
    # Core data structures
    "VoxManifest",
    "Voice",
    "Prosody",
    "ReferenceAudio",
    "Character",
    "Source",
    "Provenance",
    # I/O classes
    "VoxFile",
    "VoxReader",
    "VoxWriter",
    "VoxValidator",
    # Exceptions
    "VoxError",
    "InvalidArchive",
    "ManifestNotFound",
    "InvalidManifest",
    "InvalidReferenceAudio",
    "WriteError",
    "ValidationError",
    "EmptyRequiredField",
    "InvalidUUID",
    "InvalidTimestamp",
    "DescriptionTooShort",
    "InvalidAgeRange",
    "InvalidGender",
    "EmptyReferenceAudioPath",
    "MultipleValidationErrors",
]
