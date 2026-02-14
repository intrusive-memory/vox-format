"""VOX Manifest data structures.

This module defines Python dataclasses for representing VOX voice identity manifests.
All classes support JSON serialization and deserialization with snake_case field names.
"""

from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import Optional, List, Dict, Any
import json


@dataclass
class Source:
    """Source material reference for a character in the narrative.

    Links a character to the original screenplay, novel, or script that defines it,
    enabling traceability from voice identity back to source material.

    Attributes:
        work: Title of the source work (e.g., "The Chronicle").
        format: Format of the source material (e.g., "fountain", "screenplay", "novel").
        file: Path to the source file (e.g., "episodes/chronicle-episode-01.fountain").
    """
    work: Optional[str] = None
    format: Optional[str] = None
    file: Optional[str] = None


@dataclass
class Character:
    """Character context for screenplay-aware voice casting.

    Provides narrative context that helps casting systems select appropriate
    voice parameters. Includes the character's role, emotional range, relationships
    with other characters, and a reference to the source material.

    Attributes:
        role: Description of the character's role in the narrative.
        emotional_range: Range of emotions the character expresses.
        relationships: Character relationships mapped as character name to relationship description.
        source: Source material reference for the character.
    """
    role: Optional[str] = None
    emotional_range: Optional[List[str]] = None
    relationships: Optional[Dict[str, str]] = None
    source: Optional[Source] = None


@dataclass
class Provenance:
    """Provenance tracking for voice origin, creation method, and consent status.

    Documents how a voice was created and under what terms it may be used.
    Critical for ethical voice cloning: the method field distinguishes designed
    voices (no real person) from cloned voices (requires consent).

    Attributes:
        method: How the voice was created: "designed", "cloned", "preset", or "hybrid".
        engine: TTS engine or tool used to create the voice.
        consent: Consent status for voice cloning: "self", "granted", "unknown", or None for designed voices.
        license: License under which the voice is distributed (e.g., "CC0-1.0", "CC-BY-4.0").
        notes: Additional notes about voice provenance and creation context.
    """
    method: Optional[str] = None
    engine: Optional[str] = None
    consent: Optional[str] = None
    license: Optional[str] = None
    notes: Optional[str] = None


@dataclass
class Prosody:
    """Prosodic preferences describing the voice's natural speaking style.

    Captures qualitative descriptions of how the voice should sound in terms
    of pitch, speaking rate, energy, and default emotional tone. These are
    descriptive strings (not numeric values) to remain engine-agnostic.

    Attributes:
        pitch_base: Base pitch level (e.g., "low", "medium", "high").
        pitch_range: Pitch variation range (e.g., "narrow", "moderate", "wide").
        rate: Speaking rate (e.g., "slow", "moderate", "fast").
        energy: Overall energy or intensity level (e.g., "low", "medium", "high").
        emotion_default: Default emotional tone when no specific emotion is requested.
    """
    pitch_base: Optional[str] = None
    pitch_range: Optional[str] = None
    rate: Optional[str] = None
    energy: Optional[str] = None
    emotion_default: Optional[str] = None


@dataclass
class ReferenceAudio:
    """Metadata for a reference audio clip used in voice cloning or style matching.

    Each ReferenceAudio entry describes one audio file bundled in the .vox archive's
    reference/ directory. Audio files should be WAV format (24kHz, 16-bit PCM, mono)
    for maximum compatibility across TTS engines.

    Attributes:
        file: Path to the audio file within the .vox archive, relative to archive root.
        transcript: Verbatim transcript of the audio clip content.
        language: Language of the audio clip in BCP 47 format (e.g., "en-US").
        duration_seconds: Duration of the audio clip in seconds.
        context: Contextual note about the audio clip.
    """
    file: str = ""
    transcript: str = ""
    language: Optional[str] = None
    duration_seconds: Optional[float] = None
    context: Optional[str] = None


@dataclass
class Voice:
    """Core voice identity metadata within a VOX manifest.

    Contains the required display name and natural language description of the
    voice, along with optional attributes like language, gender, age range, and tags.
    The description field is particularly important as it serves as the primary input
    for voice design engines that generate synthetic voices from text descriptions.

    Attributes:
        name: Display name for the voice (e.g., "Narrator", "PROTAGONIST").
        description: Natural language description of the voice characteristics.
            Must be at least 10 characters. Used by voice design engines to synthesize
            or match voices. Be specific about accent, tone, age, and personality.
        language: Primary language of the voice in BCP 47 format (e.g., "en-US", "en-GB").
        gender: Gender presentation of the voice: "male", "female", "nonbinary", or "neutral".
        age_range: Approximate age range as [minimum, maximum] where minimum < maximum.
        tags: Searchable tags describing voice characteristics.
    """
    name: str = ""
    description: str = ""
    language: Optional[str] = None
    gender: Optional[str] = None
    age_range: Optional[List[int]] = None
    tags: Optional[List[str]] = None


@dataclass
class VoxManifest:
    """The root metadata structure for a VOX voice identity file.

    Represents the complete contents of the manifest.json file inside a .vox archive.
    Defines the voice identity through required fields (version, identifier, creation
    date, and voice metadata) and optional sections for prosody, reference audio,
    character context, provenance, and engine-specific extensions.

    Example:
        >>> manifest = VoxManifest(
        ...     vox_version="0.1.0",
        ...     id="ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
        ...     created="2026-02-13T12:00:00Z",
        ...     voice=Voice(
        ...         name="Narrator",
        ...         description="A warm, clear narrator voice for audiobooks."
        ...     )
        ... )
        >>> json_str = manifest.to_json()
        >>> loaded = VoxManifest.from_json(json_str)

    Attributes:
        vox_version: Semantic version of the VOX format specification (e.g., "0.1.0").
        id: Unique identifier for this voice identity in UUID v4 format.
        created: ISO 8601 timestamp of when this voice identity was created.
        voice: Core voice identity metadata including name, description, and optional attributes.
        prosody: Prosodic preferences describing the voice's natural speaking style.
        reference_audio: Reference audio clips used for voice cloning or style matching.
        character: Character context for screenplay-aware voice casting.
        provenance: Provenance tracking for voice origin and consent.
        extensions: Engine-specific extension data, keyed by provider namespace.
    """
    vox_version: str = ""
    id: str = ""
    created: str = ""  # Store as string for simplicity, can be datetime if needed
    voice: Voice = field(default_factory=Voice)
    prosody: Optional[Prosody] = None
    reference_audio: Optional[List[ReferenceAudio]] = None
    character: Optional[Character] = None
    provenance: Optional[Provenance] = None
    extensions: Optional[Dict[str, Any]] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert VoxManifest to a dictionary suitable for JSON serialization.

        Returns:
            Dictionary representation with snake_case field names and None values excluded.
        """
        def _clean_dict(obj: Any) -> Any:
            """Recursively clean dictionary by removing None values and converting dataclasses."""
            if obj is None:
                return None
            elif isinstance(obj, dict):
                return {k: _clean_dict(v) for k, v in obj.items() if v is not None}
            elif isinstance(obj, list):
                return [_clean_dict(item) for item in obj]
            elif hasattr(obj, '__dataclass_fields__'):
                return {k: _clean_dict(v) for k, v in asdict(obj).items() if v is not None}
            else:
                return obj

        result = _clean_dict(asdict(self))
        return result

    def to_json(self, indent: int = 2) -> str:
        """Convert VoxManifest to JSON string.

        Args:
            indent: Number of spaces for indentation (default: 2).

        Returns:
            Pretty-printed JSON string with sorted keys.
        """
        return json.dumps(self.to_dict(), indent=indent, sort_keys=True, ensure_ascii=False)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'VoxManifest':
        """Create VoxManifest from a dictionary.

        Args:
            data: Dictionary with manifest data (typically from JSON).

        Returns:
            VoxManifest instance.
        """
        # Handle nested Voice object
        voice_data = data.get('voice', {})
        voice = Voice(**voice_data) if voice_data else Voice()

        # Handle optional Prosody
        prosody = None
        if 'prosody' in data and data['prosody']:
            prosody = Prosody(**data['prosody'])

        # Handle optional ReferenceAudio array
        reference_audio = None
        if 'reference_audio' in data and data['reference_audio']:
            reference_audio = [ReferenceAudio(**item) for item in data['reference_audio']]

        # Handle optional Character
        character = None
        if 'character' in data and data['character']:
            char_data = data['character'].copy()
            # Handle nested Source
            if 'source' in char_data and char_data['source']:
                char_data['source'] = Source(**char_data['source'])
            character = Character(**char_data)

        # Handle optional Provenance
        provenance = None
        if 'provenance' in data and data['provenance']:
            provenance = Provenance(**data['provenance'])

        # Handle extensions (pass through as-is)
        extensions = data.get('extensions')

        return cls(
            vox_version=data.get('vox_version', ''),
            id=data.get('id', ''),
            created=data.get('created', ''),
            voice=voice,
            prosody=prosody,
            reference_audio=reference_audio,
            character=character,
            provenance=provenance,
            extensions=extensions
        )

    @classmethod
    def from_json(cls, json_str: str) -> 'VoxManifest':
        """Create VoxManifest from JSON string.

        Args:
            json_str: JSON string representation of manifest.

        Returns:
            VoxManifest instance.
        """
        data = json.loads(json_str)
        return cls.from_dict(data)
