"""VOX error exception hierarchy.

This module defines the exception classes used throughout the voxformat library.
All VOX-specific exceptions inherit from VoxError base class for easy catching.
"""


class VoxError(Exception):
    """Base exception class for all VOX-related errors.

    All voxformat exceptions inherit from this class, allowing callers to catch
    all VOX-related errors with a single except clause if desired.
    """
    pass


class InvalidArchive(VoxError):
    """Raised when a .vox file is not a valid ZIP archive.

    This error occurs when attempting to read a file with a .vox extension that
    is not actually a ZIP file, or is corrupted and cannot be opened as a ZIP.
    """
    pass


class ManifestNotFound(VoxError):
    """Raised when manifest.json is not found in the .vox archive.

    Every .vox file must contain a manifest.json file at the root of the archive.
    This error indicates the required file is missing.
    """
    pass


class InvalidManifest(VoxError):
    """Raised when manifest.json cannot be parsed or is invalid.

    This error occurs when the manifest.json file exists but contains invalid JSON,
    is missing required fields, or has malformed data that prevents proper decoding
    into a VoxManifest object.
    """
    pass


class InvalidReferenceAudio(VoxError):
    """Raised when reference audio files are missing or invalid.

    This error occurs when the manifest references audio files that cannot be found
    in the archive, or when audio file paths are malformed.
    """
    pass


class WriteError(VoxError):
    """Raised when writing a .vox file fails.

    This error occurs during .vox file creation when writing the manifest, adding
    files to the archive, or finalizing the ZIP file fails.
    """
    pass
