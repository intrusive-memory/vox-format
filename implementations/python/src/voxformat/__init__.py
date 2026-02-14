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

__all__ = [
    "VoxManifest",
    "Voice",
    "Prosody",
    "ReferenceAudio",
    "Character",
    "Source",
    "Provenance",
]
