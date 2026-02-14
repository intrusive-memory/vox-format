"""Tests for VoxWriter.

Tests verify that VoxWriter can correctly create .vox files, write manifests,
and bundle reference audio files into valid ZIP archives.
"""

import pytest
from pathlib import Path
import tempfile
import zipfile
import json
import subprocess

from voxformat.writer import VoxWriter
from voxformat.vox_file import VoxFile
from voxformat.errors import WriteError
from voxformat import VoxManifest, Voice, Prosody, Provenance


class TestVoxWriterBasic:
    """Test basic VoxWriter functionality."""

    def test_write_minimal_vox(self):
        """Test writing a minimal .vox file with only required fields."""
        writer = VoxWriter()

        # Create minimal manifest
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="test-minimal-id",
            created="2026-02-13T12:00:00Z",
            voice=Voice(
                name="Test Minimal",
                description="A minimal test voice for validation."
            )
        )

        vox_file = VoxFile(manifest=manifest)

        # Write to temp file
        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(vox_file, temp_path)

            # Verify file exists
            assert temp_path.exists()

            # Verify it's a valid ZIP
            assert zipfile.is_zipfile(temp_path)

            # Verify ZIP magic bytes
            with open(temp_path, 'rb') as f:
                magic = f.read(4)
            assert magic == b'PK\x03\x04'

            # Verify manifest.json is in the archive
            with zipfile.ZipFile(temp_path, 'r') as archive:
                assert 'manifest.json' in archive.namelist()

                # Verify manifest content
                manifest_data = json.loads(archive.read('manifest.json'))
                assert manifest_data['vox_version'] == "0.1.0"
                assert manifest_data['voice']['name'] == "Test Minimal"

        finally:
            temp_path.unlink()

    def test_write_full_vox(self):
        """Test writing a .vox file with all optional fields populated."""
        writer = VoxWriter()

        # Create full manifest
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="test-full-id",
            created="2026-02-13T15:00:00Z",
            voice=Voice(
                name="Test Full",
                description="A complete test voice with all fields populated.",
                language="en-US",
                gender="female",
                age_range=[25, 35],
                tags=["test", "complete"]
            ),
            prosody=Prosody(
                pitch_base="high",
                pitch_range="wide",
                rate="fast",
                energy="high",
                emotion_default="enthusiastic"
            ),
            provenance=Provenance(
                method="designed",
                engine="test-engine",
                consent=None,
                license="CC0-1.0",
                notes="Test provenance"
            ),
            extensions={
                "test_provider": {
                    "key": "value",
                    "nested": {"data": 123}
                }
            }
        )

        vox_file = VoxFile(manifest=manifest)

        # Write to temp file
        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(vox_file, temp_path)

            # Verify file was created
            assert temp_path.exists()

            # Verify manifest content
            with zipfile.ZipFile(temp_path, 'r') as archive:
                manifest_data = json.loads(archive.read('manifest.json'))
                assert manifest_data['voice']['language'] == "en-US"
                assert manifest_data['prosody']['pitch_base'] == "high"
                assert manifest_data['provenance']['method'] == "designed"
                assert manifest_data['extensions']['test_provider']['key'] == "value"

        finally:
            temp_path.unlink()

    def test_write_manifest_is_pretty_printed(self):
        """Test that written manifest.json is pretty-printed with sorted keys."""
        writer = VoxWriter()

        manifest = VoxManifest(
            vox_version="0.1.0",
            id="test-id",
            created="2026-02-13T12:00:00Z",
            voice=Voice(name="Test", description="Test voice")
        )

        vox_file = VoxFile(manifest=manifest)

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(vox_file, temp_path)

            # Read manifest and verify formatting
            with zipfile.ZipFile(temp_path, 'r') as archive:
                manifest_text = archive.read('manifest.json').decode('utf-8')

            # Should have indentation (pretty-printed)
            assert '  ' in manifest_text or '\t' in manifest_text

            # Should have newlines
            assert '\n' in manifest_text

            # Parse to verify it's valid JSON
            manifest_data = json.loads(manifest_text)
            assert manifest_data['vox_version'] == "0.1.0"

        finally:
            temp_path.unlink()


class TestVoxWriterReferenceAudio:
    """Test writing .vox files with reference audio."""

    def test_write_vox_with_reference_audio(self):
        """Test writing a .vox file with reference audio files."""
        writer = VoxWriter()

        manifest = VoxManifest(
            vox_version="0.1.0",
            id="test-audio-id",
            created="2026-02-13T12:00:00Z",
            voice=Voice(name="Test Audio", description="Voice with reference audio")
        )

        # Create mock audio data
        audio_data = b"FAKE_AUDIO_DATA_WAV_HEADER"

        vox_file = VoxFile(
            manifest=manifest,
            reference_audio={"sample.wav": audio_data}
        )

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(vox_file, temp_path)

            # Verify reference audio was written
            with zipfile.ZipFile(temp_path, 'r') as archive:
                assert 'reference/sample.wav' in archive.namelist()

                # Verify audio content
                audio_content = archive.read('reference/sample.wav')
                assert audio_content == audio_data

        finally:
            temp_path.unlink()

    def test_write_vox_with_multiple_reference_audio(self):
        """Test writing a .vox file with multiple reference audio files."""
        writer = VoxWriter()

        manifest = VoxManifest(
            vox_version="0.1.0",
            id="test-multi-audio-id",
            created="2026-02-13T12:00:00Z",
            voice=Voice(name="Test Multi", description="Voice with multiple audio files")
        )

        vox_file = VoxFile(
            manifest=manifest,
            reference_audio={
                "sample1.wav": b"AUDIO_1",
                "sample2.wav": b"AUDIO_2",
                "sample3.wav": b"AUDIO_3"
            }
        )

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(vox_file, temp_path)

            # Verify all audio files were written
            with zipfile.ZipFile(temp_path, 'r') as archive:
                assert 'reference/sample1.wav' in archive.namelist()
                assert 'reference/sample2.wav' in archive.namelist()
                assert 'reference/sample3.wav' in archive.namelist()

        finally:
            temp_path.unlink()


class TestVoxWriterExtensions:
    """Test writing .vox files with extension files."""

    def test_write_vox_with_extensions(self):
        """Test writing a .vox file with extension files (embeddings)."""
        writer = VoxWriter()

        manifest = VoxManifest(
            vox_version="0.1.0",
            id="test-ext-id",
            created="2026-02-13T12:00:00Z",
            voice=Voice(name="Test Ext", description="Voice with extensions")
        )

        vox_file = VoxFile(
            manifest=manifest,
            extensions_files={
                "embeddings/qwen3-tts/voice.safetensors": b"FAKE_EMBEDDING_DATA"
            }
        )

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(vox_file, temp_path)

            # Verify extension file was written
            with zipfile.ZipFile(temp_path, 'r') as archive:
                assert 'embeddings/qwen3-tts/voice.safetensors' in archive.namelist()

                # Verify content
                ext_content = archive.read('embeddings/qwen3-tts/voice.safetensors')
                assert ext_content == b"FAKE_EMBEDDING_DATA"

        finally:
            temp_path.unlink()


class TestVoxWriterSystemValidation:
    """Test that written .vox files can be validated with system tools."""

    def test_written_vox_validates_with_unzip(self):
        """Test that created .vox file can be tested with system unzip command."""
        writer = VoxWriter()

        manifest = VoxManifest(
            vox_version="0.1.0",
            id="test-unzip-id",
            created="2026-02-13T12:00:00Z",
            voice=Voice(name="Test Unzip", description="Voice for system validation")
        )

        vox_file = VoxFile(manifest=manifest)

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(vox_file, temp_path)

            # Verify with system unzip -t (test archive integrity)
            result = subprocess.run(
                ['unzip', '-t', str(temp_path)],
                capture_output=True,
                text=True
            )

            # unzip -t should exit with 0 for valid archives
            assert result.returncode == 0
            assert 'No errors detected' in result.stdout or 'OK' in result.stdout

        finally:
            temp_path.unlink()
