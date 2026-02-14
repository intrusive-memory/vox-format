"""Tests for VoxManifest JSON decoding and encoding.

Tests verify that VoxManifest can correctly decode all example manifest files
and perform roundtrip encoding/decoding without data loss.
"""

import json
import pytest
from pathlib import Path

from voxformat import VoxManifest, Voice, Prosody, Provenance


# Path to examples directory (relative to project root)
EXAMPLES_DIR = Path(__file__).parent.parent.parent.parent / "examples"


class TestManifestDecoding:
    """Test decoding of example manifest files."""

    def test_decode_minimal_manifest(self):
        """Test decoding minimal manifest with only required fields."""
        manifest_path = EXAMPLES_DIR / "minimal" / "manifest.json"

        with open(manifest_path, 'r') as f:
            json_str = f.read()

        manifest = VoxManifest.from_json(json_str)

        # Verify required fields
        assert manifest.vox_version == "0.1.0"
        assert manifest.id == "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78"
        assert manifest.created == "2026-02-13T12:00:00Z"

        # Verify voice fields
        assert manifest.voice.name == "Narrator"
        assert manifest.voice.description == "A warm, clear narrator voice with neutral accent suitable for audiobooks and documentaries."

        # Verify optional fields are None
        assert manifest.voice.language is None
        assert manifest.voice.gender is None
        assert manifest.voice.age_range is None
        assert manifest.voice.tags is None
        assert manifest.prosody is None
        assert manifest.reference_audio is None
        assert manifest.character is None
        assert manifest.provenance is None
        assert manifest.extensions is None

    def test_decode_multi_engine_manifest(self):
        """Test decoding multi-engine manifest with extensions and prosody."""
        manifest_path = EXAMPLES_DIR / "multi-engine" / "manifest.json"

        with open(manifest_path, 'r') as f:
            json_str = f.read()

        manifest = VoxManifest.from_json(json_str)

        # Verify required fields
        assert manifest.vox_version == "0.1.0"
        assert manifest.id == "7ca7b257-e94a-43ae-adae-c60116fb8a8a"

        # Verify voice fields with optional attributes
        assert manifest.voice.name == "VERSATILE"
        assert manifest.voice.language == "en-US"
        assert manifest.voice.gender == "male"
        assert manifest.voice.age_range == [28, 35]
        assert manifest.voice.tags == ["versatile", "professional", "conversational", "neutral"]

        # Verify prosody
        assert manifest.prosody is not None
        assert manifest.prosody.pitch_base == "medium"
        assert manifest.prosody.pitch_range == "moderate"
        assert manifest.prosody.rate == "medium"
        assert manifest.prosody.energy == "medium"
        assert manifest.prosody.emotion_default == "friendly professionalism"

        # Verify provenance
        assert manifest.provenance is not None
        assert manifest.provenance.method == "designed"
        assert manifest.provenance.engine == "multi-platform"
        assert manifest.provenance.consent is None
        assert manifest.provenance.license == "CC0-1.0"

        # Verify extensions
        assert manifest.extensions is not None
        assert "apple" in manifest.extensions
        assert "elevenlabs" in manifest.extensions
        assert "qwen3-tts" in manifest.extensions

        # Verify nested extension data
        assert manifest.extensions["apple"]["voice_id"] == "en-US/Aaron"
        assert manifest.extensions["elevenlabs"]["voice_id"] == "vid-example-abc123"
        assert manifest.extensions["qwen3-tts"]["model"] == "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"

    def test_decode_with_direct_dict_construction(self):
        """Test decoding a manifest constructed as a Python dict."""
        data = {
            "vox_version": "0.1.0",
            "id": "test-uuid-1234",
            "created": "2026-02-13T14:30:00Z",
            "voice": {
                "name": "Test Voice",
                "description": "A test voice for validation purposes."
            }
        }

        manifest = VoxManifest.from_dict(data)

        assert manifest.vox_version == "0.1.0"
        assert manifest.id == "test-uuid-1234"
        assert manifest.voice.name == "Test Voice"


class TestManifestEncoding:
    """Test encoding and roundtrip fidelity."""

    def test_roundtrip_minimal_manifest(self):
        """Test encoding and decoding minimal manifest preserves all data."""
        # Create minimal manifest
        original = VoxManifest(
            vox_version="0.1.0",
            id="ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created="2026-02-13T12:00:00Z",
            voice=Voice(
                name="Narrator",
                description="A warm, clear narrator voice with neutral accent suitable for audiobooks and documentaries."
            )
        )

        # Encode to JSON
        json_str = original.to_json()

        # Decode back
        decoded = VoxManifest.from_json(json_str)

        # Verify all fields match
        assert decoded.vox_version == original.vox_version
        assert decoded.id == original.id
        assert decoded.created == original.created
        assert decoded.voice.name == original.voice.name
        assert decoded.voice.description == original.voice.description

    def test_roundtrip_full_manifest(self):
        """Test encoding and decoding manifest with all optional fields."""
        # Create manifest with all fields populated
        original = VoxManifest(
            vox_version="0.1.0",
            id="test-uuid-full",
            created="2026-02-13T15:00:00Z",
            voice=Voice(
                name="Full Voice",
                description="A voice with all optional fields populated for testing.",
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

        # Encode to JSON
        json_str = original.to_json()

        # Decode back
        decoded = VoxManifest.from_json(json_str)

        # Verify required fields
        assert decoded.vox_version == original.vox_version
        assert decoded.id == original.id

        # Verify voice fields
        assert decoded.voice.name == original.voice.name
        assert decoded.voice.language == original.voice.language
        assert decoded.voice.gender == original.voice.gender
        assert decoded.voice.age_range == original.voice.age_range
        assert decoded.voice.tags == original.voice.tags

        # Verify prosody
        assert decoded.prosody is not None
        assert decoded.prosody.pitch_base == original.prosody.pitch_base
        assert decoded.prosody.rate == original.prosody.rate

        # Verify provenance
        assert decoded.provenance is not None
        assert decoded.provenance.method == original.provenance.method
        assert decoded.provenance.license == original.provenance.license

        # Verify extensions
        assert decoded.extensions is not None
        assert decoded.extensions["test_provider"]["key"] == "value"
        assert decoded.extensions["test_provider"]["nested"]["data"] == 123

    def test_to_dict_excludes_none_values(self):
        """Test that to_dict excludes None values for cleaner JSON output."""
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="test-id",
            created="2026-02-13T12:00:00Z",
            voice=Voice(
                name="Test",
                description="Test description"
            )
        )

        manifest_dict = manifest.to_dict()

        # Should not include optional fields that are None
        assert "prosody" not in manifest_dict
        assert "reference_audio" not in manifest_dict
        assert "character" not in manifest_dict
        assert "provenance" not in manifest_dict
        assert "extensions" not in manifest_dict

        # Voice should not include None fields
        assert "language" not in manifest_dict["voice"]
        assert "gender" not in manifest_dict["voice"]
        assert "age_range" not in manifest_dict["voice"]
        assert "tags" not in manifest_dict["voice"]

    def test_json_has_sorted_keys(self):
        """Test that JSON output has sorted keys for consistency."""
        manifest = VoxManifest(
            vox_version="0.1.0",
            id="test-id",
            created="2026-02-13T12:00:00Z",
            voice=Voice(name="Test", description="Test description")
        )

        json_str = manifest.to_json()

        # Parse and verify key order
        lines = json_str.strip().split('\n')

        # First key should be 'created' (alphabetically first among required fields)
        assert '"created"' in lines[1]
        # 'id' comes next
        assert '"id"' in lines[2]
        # 'voice' after that
        assert '"voice"' in lines[3]
        # 'vox_version' last
        assert '"vox_version"' in lines[-2]
