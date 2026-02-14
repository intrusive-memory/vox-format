"""VOX file reader for extracting and parsing .vox archives.

This module provides the VoxReader class for reading .vox files from disk,
extracting their contents, and parsing the manifest and bundled assets.
"""

import json
import zipfile
from pathlib import Path
from typing import Dict, Optional

from .manifest import VoxManifest
from .vox_file import VoxFile
from .errors import InvalidArchive, ManifestNotFound, InvalidManifest


class VoxReader:
    """Reader for extracting and parsing VOX voice identity files.

    VoxReader handles opening .vox ZIP archives, extracting the manifest.json,
    parsing it into a VoxManifest object, and reading any bundled reference audio
    or extension files.

    Example:
        >>> reader = VoxReader()
        >>> vox_file = reader.read(Path("narrator.vox"))
        >>> print(vox_file.manifest.voice.name)
        Narrator
        >>> if vox_file.reference_audio:
        ...     print(f"Found {len(vox_file.reference_audio)} audio files")
    """

    def read(self, file_path: Path) -> VoxFile:
        """Read and parse a .vox file from disk.

        Args:
            file_path: Path to the .vox file to read.

        Returns:
            VoxFile containing the parsed manifest and bundled assets.

        Raises:
            InvalidArchive: If the file is not a valid ZIP archive.
            ManifestNotFound: If manifest.json is not found at archive root.
            InvalidManifest: If manifest.json cannot be parsed or is invalid.
        """
        # Open the ZIP archive
        try:
            archive = zipfile.ZipFile(file_path, 'r')
        except zipfile.BadZipFile as e:
            raise InvalidArchive(f"File is not a valid ZIP archive: {file_path}") from e
        except (FileNotFoundError, OSError) as e:
            raise InvalidArchive(f"Cannot open file: {file_path}") from e

        try:
            # Extract and parse manifest.json
            manifest = self._read_manifest(archive)

            # Extract reference audio files
            reference_audio = self._read_reference_audio(archive, manifest)

            # Extract extension files (embeddings, etc.)
            extensions_files = self._read_extensions(archive)

            return VoxFile(
                manifest=manifest,
                reference_audio=reference_audio if reference_audio else None,
                extensions_files=extensions_files if extensions_files else None
            )
        finally:
            archive.close()

    def _read_manifest(self, archive: zipfile.ZipFile) -> VoxManifest:
        """Read and parse manifest.json from the archive.

        Args:
            archive: Opened ZIP archive.

        Returns:
            Parsed VoxManifest object.

        Raises:
            ManifestNotFound: If manifest.json is not in the archive.
            InvalidManifest: If manifest.json cannot be parsed.
        """
        manifest_path = "manifest.json"

        # Check if manifest.json exists
        if manifest_path not in archive.namelist():
            raise ManifestNotFound(f"manifest.json not found in archive")

        # Read manifest.json
        try:
            manifest_bytes = archive.read(manifest_path)
            manifest_str = manifest_bytes.decode('utf-8')
        except (KeyError, UnicodeDecodeError) as e:
            raise InvalidManifest(f"Cannot read manifest.json: {e}") from e

        # Parse JSON
        try:
            manifest_data = json.loads(manifest_str)
        except json.JSONDecodeError as e:
            raise InvalidManifest(f"Invalid JSON in manifest.json: {e}") from e

        # Decode into VoxManifest
        try:
            manifest = VoxManifest.from_dict(manifest_data)
        except Exception as e:
            raise InvalidManifest(f"Cannot decode manifest: {e}") from e

        return manifest

    def _read_reference_audio(
        self,
        archive: zipfile.ZipFile,
        manifest: VoxManifest
    ) -> Dict[str, bytes]:
        """Read reference audio files from the archive.

        Reads all files in the reference/ directory. If manifest.reference_audio
        is specified, prioritizes those files, but also includes any other files
        found in the reference/ directory.

        Args:
            archive: Opened ZIP archive.
            manifest: Parsed manifest containing reference_audio entries.

        Returns:
            Dictionary mapping filenames to audio file bytes.
        """
        reference_audio = {}

        # First, try to read files mentioned in manifest
        if manifest.reference_audio:
            for audio_entry in manifest.reference_audio:
                file_path = audio_entry.file
                if not file_path:
                    continue

                # Try to read the file from the archive
                try:
                    audio_bytes = archive.read(file_path)
                    # Store with just the filename as key (strip directory)
                    filename = Path(file_path).name
                    reference_audio[filename] = audio_bytes
                except KeyError:
                    # File not found in archive - handle gracefully
                    # Don't raise error, just skip missing files
                    continue

        # Also scan the reference/ directory for any other audio files
        for file_info in archive.infolist():
            if file_info.filename.startswith('reference/') and not file_info.is_dir():
                filename = Path(file_info.filename).name
                # Only add if not already present
                if filename not in reference_audio:
                    try:
                        audio_bytes = archive.read(file_info.filename)
                        reference_audio[filename] = audio_bytes
                    except KeyError:
                        continue

        return reference_audio

    def _read_extensions(self, archive: zipfile.ZipFile) -> Dict[str, bytes]:
        """Read extension files (embeddings, etc.) from the archive.

        Args:
            archive: Opened ZIP archive.

        Returns:
            Dictionary mapping relative file paths to file bytes.
        """
        extensions_files = {}

        # Look for any files in embeddings/ directory
        for file_info in archive.infolist():
            if file_info.filename.startswith('embeddings/') and not file_info.is_dir():
                try:
                    file_bytes = archive.read(file_info.filename)
                    extensions_files[file_info.filename] = file_bytes
                except KeyError:
                    continue

        return extensions_files
