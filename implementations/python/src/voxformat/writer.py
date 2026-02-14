"""VOX file writer for creating .vox archives.

This module provides the VoxWriter class for creating .vox files by encoding
a VoxManifest to JSON and packaging it with reference audio and extension files
into a ZIP archive.
"""

import zipfile
from pathlib import Path

from .vox_file import VoxFile
from .errors import WriteError


class VoxWriter:
    """Writer for creating VOX voice identity files.

    VoxWriter handles encoding a VoxManifest to JSON, creating a ZIP archive,
    and adding reference audio and extension files to create a complete .vox file.

    Example:
        >>> from voxformat import VoxManifest, Voice, VoxFile
        >>> manifest = VoxManifest(
        ...     vox_version="0.1.0",
        ...     id="unique-id",
        ...     created="2026-02-13T12:00:00Z",
        ...     voice=Voice(name="Test", description="A test voice")
        ... )
        >>> vox_file = VoxFile(manifest=manifest)
        >>> writer = VoxWriter()
        >>> writer.write(vox_file, Path("output.vox"))
    """

    def write(self, vox_file: VoxFile, output_path: Path) -> None:
        """Write a VoxFile to disk as a .vox archive.

        Args:
            vox_file: VoxFile containing manifest and optional assets to write.
            output_path: Path where the .vox file should be created.

        Raises:
            WriteError: If writing the .vox file fails.
        """
        try:
            # Create ZIP archive with DEFLATE compression
            with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as archive:
                # Write manifest.json
                self._write_manifest(archive, vox_file.manifest)

                # Write reference audio files
                if vox_file.reference_audio:
                    self._write_reference_audio(archive, vox_file.reference_audio)

                # Write extension files
                if vox_file.extensions_files:
                    self._write_extensions(archive, vox_file.extensions_files)

            # Verify ZIP magic bytes
            self._verify_zip_format(output_path)

        except Exception as e:
            raise WriteError(f"Failed to write .vox file: {e}") from e

    def _write_manifest(self, archive: zipfile.ZipFile, manifest) -> None:
        """Write manifest.json to the archive root.

        Args:
            archive: Opened ZIP archive in write mode.
            manifest: VoxManifest to encode and write.
        """
        # Encode manifest to pretty-printed JSON
        manifest_json = manifest.to_json(indent=2)

        # Write to archive root
        archive.writestr('manifest.json', manifest_json)

    def _write_reference_audio(self, archive: zipfile.ZipFile, reference_audio: dict) -> None:
        """Write reference audio files to the archive.

        Args:
            archive: Opened ZIP archive in write mode.
            reference_audio: Dictionary mapping filenames to audio bytes.
        """
        for filename, audio_bytes in reference_audio.items():
            # Write to reference/ directory
            archive_path = f"reference/{filename}"
            archive.writestr(archive_path, audio_bytes)

    def _write_extensions(self, archive: zipfile.ZipFile, extensions_files: dict) -> None:
        """Write extension files to the archive.

        Args:
            archive: Opened ZIP archive in write mode.
            extensions_files: Dictionary mapping relative paths to file bytes.
        """
        for file_path, file_bytes in extensions_files.items():
            archive.writestr(file_path, file_bytes)

    def _verify_zip_format(self, file_path: Path) -> None:
        """Verify that the created file has valid ZIP magic bytes.

        Args:
            file_path: Path to the created .vox file.

        Raises:
            WriteError: If the file doesn't have ZIP magic bytes.
        """
        with open(file_path, 'rb') as f:
            magic_bytes = f.read(4)

        if magic_bytes != b'PK\x03\x04':
            raise WriteError(f"Created file does not have ZIP magic bytes: {file_path}")
