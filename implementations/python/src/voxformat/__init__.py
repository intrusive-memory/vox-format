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
from .errors import (
    VoxError,
    InvalidArchive,
    ManifestNotFound,
    InvalidManifest,
    InvalidReferenceAudio,
    WriteError,
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
    # Exceptions
    "VoxError",
    "InvalidArchive",
    "ManifestNotFound",
    "InvalidManifest",
    "InvalidReferenceAudio",
    "WriteError",
]
