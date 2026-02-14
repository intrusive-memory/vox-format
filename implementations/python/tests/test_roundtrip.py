"""Roundtrip tests for VoxReader and VoxWriter.

Tests verify that writing a VoxManifest to a .vox file and reading it back
produces identical data, ensuring no data loss during the write/read cycle.
"""

import pytest
from pathlib import Path
import tempfile

from voxformat import VoxManifest, Voice, Prosody, ReferenceAudio, Provenance, Character, Source
from voxformat.vox_file import VoxFile
from voxformat.reader import VoxReader
from voxformat.writer import VoxWriter


# Path to examples directory (relative to project root)
EXAMPLES_DIR = Path(__file__).parent.parent.parent.parent / "examples"


class TestRoundtripMinimal:
    """Test roundtrip for minimal manifests."""

    def test_roundtrip_minimal_manifest(self):
        """Test write then read of minimal manifest preserves all data."""
        writer = VoxWriter()
        reader = VoxReader()

        # Create minimal manifest
        original_manifest = VoxManifest(
            vox_version="0.1.0",
            id="roundtrip-test-minimal",
            created="2026-02-13T12:00:00Z",
            voice=Voice(
                name="Roundtrip Test",
                description="A minimal voice for roundtrip testing."
            )
        )

        original_vox = VoxFile(manifest=original_manifest)

        # Write to temp file
        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(original_vox, temp_path)

            # Read back
            read_vox = reader.read(temp_path)

            # Compare manifests
            assert read_vox.manifest.vox_version == original_manifest.vox_version
            assert read_vox.manifest.id == original_manifest.id
            assert read_vox.manifest.created == original_manifest.created
            assert read_vox.manifest.voice.name == original_manifest.voice.name
            assert read_vox.manifest.voice.description == original_manifest.voice.description

        finally:
            temp_path.unlink()


class TestRoundtripFull:
    """Test roundtrip for full manifests with all optional fields."""

    def test_roundtrip_full_manifest(self):
        """Test write then read of full manifest with all fields populated."""
        writer = VoxWriter()
        reader = VoxReader()

        # Create full manifest
        original_manifest = VoxManifest(
            vox_version="0.1.0",
            id="roundtrip-test-full",
            created="2026-02-13T15:00:00Z",
            voice=Voice(
                name="Full Roundtrip",
                description="A complete voice with all fields for roundtrip testing.",
                language="en-GB",
                gender="nonbinary",
                age_range=[30, 40],
                tags=["roundtrip", "complete", "test"]
            ),
            prosody=Prosody(
                pitch_base="medium",
                pitch_range="moderate",
                rate="medium",
                energy="medium",
                emotion_default="neutral"
            ),
            provenance=Provenance(
                method="designed",
                engine="test-roundtrip-engine",
                consent=None,
                license="CC0-1.0",
                notes="Created for roundtrip testing"
            ),
            extensions={
                "test_engine": {
                    "model": "test-model-v1",
                    "parameters": {
                        "temperature": 0.7,
                        "seed": 42
                    }
                }
            }
        )

        original_vox = VoxFile(manifest=original_manifest)

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(original_vox, temp_path)
            read_vox = reader.read(temp_path)

            # Compare required fields
            assert read_vox.manifest.vox_version == original_manifest.vox_version
            assert read_vox.manifest.id == original_manifest.id
            assert read_vox.manifest.created == original_manifest.created

            # Compare voice fields
            assert read_vox.manifest.voice.name == original_manifest.voice.name
            assert read_vox.manifest.voice.description == original_manifest.voice.description
            assert read_vox.manifest.voice.language == original_manifest.voice.language
            assert read_vox.manifest.voice.gender == original_manifest.voice.gender
            assert read_vox.manifest.voice.age_range == original_manifest.voice.age_range
            assert read_vox.manifest.voice.tags == original_manifest.voice.tags

            # Compare prosody
            assert read_vox.manifest.prosody.pitch_base == original_manifest.prosody.pitch_base
            assert read_vox.manifest.prosody.pitch_range == original_manifest.prosody.pitch_range
            assert read_vox.manifest.prosody.rate == original_manifest.prosody.rate
            assert read_vox.manifest.prosody.energy == original_manifest.prosody.energy
            assert read_vox.manifest.prosody.emotion_default == original_manifest.prosody.emotion_default

            # Compare provenance
            assert read_vox.manifest.provenance.method == original_manifest.provenance.method
            assert read_vox.manifest.provenance.engine == original_manifest.provenance.engine
            assert read_vox.manifest.provenance.consent == original_manifest.provenance.consent
            assert read_vox.manifest.provenance.license == original_manifest.provenance.license
            assert read_vox.manifest.provenance.notes == original_manifest.provenance.notes

            # Compare extensions
            assert read_vox.manifest.extensions["test_engine"]["model"] == "test-model-v1"
            assert read_vox.manifest.extensions["test_engine"]["parameters"]["temperature"] == 0.7
            assert read_vox.manifest.extensions["test_engine"]["parameters"]["seed"] == 42

        finally:
            temp_path.unlink()


class TestRoundtripWithAssets:
    """Test roundtrip for .vox files with reference audio and extensions."""

    def test_roundtrip_with_reference_audio(self):
        """Test write then read preserves reference audio files."""
        writer = VoxWriter()
        reader = VoxReader()

        manifest = VoxManifest(
            vox_version="0.1.0",
            id="roundtrip-audio-test",
            created="2026-02-13T12:00:00Z",
            voice=Voice(name="Audio Test", description="Voice with reference audio")
        )

        # Create mock audio data
        audio_data = b"MOCK_WAV_DATA_HEADER_12345"

        original_vox = VoxFile(
            manifest=manifest,
            reference_audio={"sample.wav": audio_data}
        )

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(original_vox, temp_path)
            read_vox = reader.read(temp_path)

            # Verify audio was preserved
            assert read_vox.reference_audio is not None
            assert "sample.wav" in read_vox.reference_audio
            assert read_vox.reference_audio["sample.wav"] == audio_data

        finally:
            temp_path.unlink()

    def test_roundtrip_with_extensions_files(self):
        """Test write then read preserves extension files."""
        writer = VoxWriter()
        reader = VoxReader()

        manifest = VoxManifest(
            vox_version="0.1.0",
            id="roundtrip-ext-test",
            created="2026-02-13T12:00:00Z",
            voice=Voice(name="Extensions Test", description="Voice with extension files")
        )

        # Create mock embedding data
        embedding_data = b"MOCK_EMBEDDING_TENSOR_DATA"

        original_vox = VoxFile(
            manifest=manifest,
            extensions_files={"embeddings/test/model.bin": embedding_data}
        )

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(original_vox, temp_path)
            read_vox = reader.read(temp_path)

            # Verify extension files were preserved
            assert read_vox.extensions_files is not None
            assert "embeddings/test/model.bin" in read_vox.extensions_files
            assert read_vox.extensions_files["embeddings/test/model.bin"] == embedding_data

        finally:
            temp_path.unlink()


class TestRoundtripExampleFiles:
    """Test roundtrip for all example .vox files."""

    def test_roundtrip_minimal_example(self):
        """Test roundtrip of examples/minimal/narrator.vox."""
        reader = VoxReader()
        writer = VoxWriter()

        original_path = EXAMPLES_DIR / "minimal" / "narrator.vox"
        original_vox = reader.read(original_path)

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(original_vox, temp_path)
            read_vox = reader.read(temp_path)

            # Compare manifests
            assert read_vox.manifest.vox_version == original_vox.manifest.vox_version
            assert read_vox.manifest.id == original_vox.manifest.id
            assert read_vox.manifest.voice.name == original_vox.manifest.voice.name
            assert read_vox.manifest.voice.description == original_vox.manifest.voice.description

        finally:
            temp_path.unlink()

    def test_roundtrip_multi_engine_example(self):
        """Test roundtrip of examples/multi-engine/cross-platform.vox."""
        reader = VoxReader()
        writer = VoxWriter()

        original_path = EXAMPLES_DIR / "multi-engine" / "cross-platform.vox"
        original_vox = reader.read(original_path)

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(original_vox, temp_path)
            read_vox = reader.read(temp_path)

            # Compare manifests
            assert read_vox.manifest.vox_version == original_vox.manifest.vox_version
            assert read_vox.manifest.voice.name == original_vox.manifest.voice.name

            # Verify extensions preserved
            assert read_vox.manifest.extensions is not None
            assert "apple" in read_vox.manifest.extensions
            assert "elevenlabs" in read_vox.manifest.extensions
            assert "qwen3-tts" in read_vox.manifest.extensions

        finally:
            temp_path.unlink()

    def test_roundtrip_character_context_example(self):
        """Test roundtrip of examples/character/narrator-with-context.vox."""
        reader = VoxReader()
        writer = VoxWriter()

        original_path = EXAMPLES_DIR / "character" / "narrator-with-context.vox"
        original_vox = reader.read(original_path)

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(original_vox, temp_path)
            read_vox = reader.read(temp_path)

            # Compare manifests
            assert read_vox.manifest.vox_version == original_vox.manifest.vox_version
            assert read_vox.manifest.voice.name == original_vox.manifest.voice.name

            # Verify character context preserved
            if original_vox.manifest.character:
                assert read_vox.manifest.character is not None
                assert read_vox.manifest.character.role == original_vox.manifest.character.role

        finally:
            temp_path.unlink()

    def test_roundtrip_library_voice(self):
        """Test roundtrip of a library voice."""
        reader = VoxReader()
        writer = VoxWriter()

        original_path = EXAMPLES_DIR / "library" / "narrators" / "audiobook.vox"
        original_vox = reader.read(original_path)

        with tempfile.NamedTemporaryFile(suffix=".vox", delete=False) as f:
            temp_path = Path(f.name)

        try:
            writer.write(original_vox, temp_path)
            read_vox = reader.read(temp_path)

            # Compare manifests
            assert read_vox.manifest.vox_version == original_vox.manifest.vox_version
            assert read_vox.manifest.voice.name == original_vox.manifest.voice.name
            assert read_vox.manifest.voice.description == original_vox.manifest.voice.description

        finally:
            temp_path.unlink()
