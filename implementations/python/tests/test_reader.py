"""Tests for VoxReader.

Tests verify that VoxReader can correctly read .vox files, extract manifests,
and handle various error conditions gracefully.
"""

import pytest
from pathlib import Path
import tempfile
import zipfile

from voxformat.reader import VoxReader
from voxformat.errors import InvalidArchive, ManifestNotFound, InvalidManifest
from voxformat import VoxManifest, Voice


# Path to examples directory (relative to project root)
EXAMPLES_DIR = Path(__file__).parent.parent.parent.parent / "examples"


class TestVoxReaderValid:
    """Test reading valid .vox files."""

    def test_read_minimal_vox(self):
        """Test reading minimal narrator.vox with only required fields."""
        reader = VoxReader()
        vox_path = EXAMPLES_DIR / "minimal" / "narrator.vox"

        vox_file = reader.read(vox_path)

        # Verify manifest was parsed
        assert vox_file.manifest is not None
        assert vox_file.manifest.vox_version == "0.1.0"
        assert vox_file.manifest.voice.name == "Narrator"
        assert len(vox_file.manifest.voice.description) > 10

        # Minimal example has no reference audio
        assert vox_file.reference_audio is None or len(vox_file.reference_audio) == 0

    def test_read_multi_engine_vox(self):
        """Test reading cross-platform.vox with extensions."""
        reader = VoxReader()
        vox_path = EXAMPLES_DIR / "multi-engine" / "cross-platform.vox"

        vox_file = reader.read(vox_path)

        # Verify manifest was parsed
        assert vox_file.manifest is not None
        assert vox_file.manifest.voice.name == "VERSATILE"

        # Verify extensions were parsed
        assert vox_file.manifest.extensions is not None
        assert "apple" in vox_file.manifest.extensions
        assert "elevenlabs" in vox_file.manifest.extensions
        assert "qwen3-tts" in vox_file.manifest.extensions

    def test_read_character_with_context_vox(self):
        """Test reading narrator-with-context.vox with character metadata."""
        reader = VoxReader()
        vox_path = EXAMPLES_DIR / "character" / "narrator-with-context.vox"

        vox_file = reader.read(vox_path)

        # Verify manifest was parsed
        assert vox_file.manifest is not None
        assert vox_file.manifest.voice.name == "NARRATOR"

        # Verify character context
        assert vox_file.manifest.character is not None
        assert vox_file.manifest.character.role is not None

    def test_read_library_voice(self):
        """Test reading a voice from the library."""
        reader = VoxReader()
        vox_path = EXAMPLES_DIR / "library" / "narrators" / "audiobook.vox"

        vox_file = reader.read(vox_path)

        # Verify manifest was parsed
        assert vox_file.manifest is not None
        assert vox_file.manifest.voice.name is not None
        assert len(vox_file.manifest.voice.description) > 10


class TestVoxReaderErrors:
    """Test error handling in VoxReader."""

    def test_read_nonexistent_file(self):
        """Test reading a file that doesn't exist."""
        reader = VoxReader()
        fake_path = Path("/tmp/nonexistent-file-12345.vox")

        with pytest.raises(InvalidArchive):
            reader.read(fake_path)

    def test_read_non_zip_file(self):
        """Test reading a file that is not a ZIP archive."""
        reader = VoxReader()

        # Create a temporary text file with .vox extension
        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            f.write(b"This is not a ZIP file")
            temp_path = Path(f.name)

        try:
            with pytest.raises(InvalidArchive) as exc_info:
                reader.read(temp_path)
            assert "not a valid ZIP archive" in str(exc_info.value)
        finally:
            temp_path.unlink()

    def test_read_zip_without_manifest(self):
        """Test reading a ZIP file that doesn't contain manifest.json."""
        reader = VoxReader()

        # Create a temporary ZIP file without manifest.json
        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            with zipfile.ZipFile(temp_path, 'w') as archive:
                archive.writestr('other_file.txt', 'Not a manifest')

            with pytest.raises(ManifestNotFound) as exc_info:
                reader.read(temp_path)
            assert "manifest.json not found" in str(exc_info.value)
        finally:
            temp_path.unlink()

    def test_read_zip_with_invalid_json_manifest(self):
        """Test reading a ZIP with malformed JSON in manifest.json."""
        reader = VoxReader()

        # Create a temporary ZIP file with invalid JSON
        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            with zipfile.ZipFile(temp_path, 'w') as archive:
                archive.writestr('manifest.json', '{invalid json}')

            with pytest.raises(InvalidManifest) as exc_info:
                reader.read(temp_path)
            assert "Invalid JSON" in str(exc_info.value)
        finally:
            temp_path.unlink()

    def test_read_zip_with_incomplete_manifest(self):
        """Test reading a ZIP with manifest missing required fields."""
        reader = VoxReader()

        # Create a temporary ZIP file with incomplete manifest
        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            with zipfile.ZipFile(temp_path, 'w') as archive:
                # Missing required fields like vox_version, id, etc.
                archive.writestr('manifest.json', '{"voice": {}}')

            # This should still parse but have empty/default values
            vox_file = reader.read(temp_path)
            assert vox_file.manifest is not None
        finally:
            temp_path.unlink()


class TestVoxReaderReferenceAudio:
    """Test reading reference audio from .vox files."""

    def test_read_vox_with_missing_reference_audio(self):
        """Test that missing reference audio files are handled gracefully."""
        reader = VoxReader()

        # Create a .vox with manifest referencing non-existent audio
        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            manifest = VoxManifest(
                vox_version="0.1.0",
                id="test-id",
                created="2026-02-13T12:00:00Z",
                voice=Voice(name="Test", description="Test voice")
            )

            with zipfile.ZipFile(temp_path, 'w') as archive:
                archive.writestr('manifest.json', manifest.to_json())

            # Should read successfully without reference audio
            vox_file = reader.read(temp_path)
            assert vox_file.reference_audio is None or len(vox_file.reference_audio) == 0
        finally:
            temp_path.unlink()

    def test_read_vox_with_non_utf8_manifest(self):
        """Test reading a ZIP with non-UTF-8 encoded manifest.json."""
        reader = VoxReader()

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            with zipfile.ZipFile(temp_path, 'w') as archive:
                # Write manifest with invalid UTF-8 encoding
                archive.writestr('manifest.json', b'\xff\xfe Invalid UTF-8')

            with pytest.raises(InvalidManifest) as exc_info:
                reader.read(temp_path)
            assert "Cannot read manifest.json" in str(exc_info.value)
        finally:
            temp_path.unlink()

    def test_read_vox_with_corrupt_manifest_data(self):
        """Test reading manifest with data that cannot be decoded into VoxManifest."""
        reader = VoxReader()

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            with zipfile.ZipFile(temp_path, 'w') as archive:
                # Write valid JSON but with unexpected structure
                archive.writestr('manifest.json', '{"unexpected": "structure"}')

            # This should still parse but have empty/default values
            vox_file = reader.read(temp_path)
            assert vox_file.manifest is not None
        finally:
            temp_path.unlink()
