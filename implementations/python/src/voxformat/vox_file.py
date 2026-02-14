"""VOX file data container.

This module defines the VoxFile dataclass that represents a complete .vox file
including the manifest and references to bundled assets like reference audio.
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Dict

from .manifest import VoxManifest


@dataclass(frozen=True)
class VoxFile:
    """Container for a complete VOX voice identity file.

    Represents the fully parsed contents of a .vox archive including the manifest
    and file paths to any bundled assets. This is the primary return type from
    VoxReader and input type to VoxWriter.

    The class is immutable (frozen=True) to prevent accidental modification of
    the parsed data.

    Attributes:
        manifest: The parsed VoxManifest containing voice metadata.
        reference_audio: Dictionary mapping reference audio filenames to their binary content.
            Keys are filenames as referenced in manifest.reference_audio[].file.
            Values are the raw bytes of the audio files.
        extensions_files: Dictionary mapping extension file paths to their binary content.
            Keys are relative paths like "embeddings/qwen3-tts/voice.safetensors".
            Values are the raw bytes of the extension files.

    Example:
        >>> vox_file = VoxFile(
        ...     manifest=manifest,
        ...     reference_audio={"sample.wav": audio_bytes},
        ...     extensions_files={"embeddings/qwen3-tts/voice.safetensors": embedding_bytes}
        ... )
    """
    manifest: VoxManifest
    reference_audio: Optional[Dict[str, bytes]] = None
    extensions_files: Optional[Dict[str, bytes]] = None
