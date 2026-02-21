# VOX: Open Voice Identity Format

**Status:** Draft / RFC  
**Version:** 0.2.0  
**Authors:** intrusive-memory  
**Repository:** [SwiftEchada](https://github.com/intrusive-memory/SwiftEchada)

---

## Abstract

VOX (`.vox`) is an open, vendor-neutral file format for persisting voice identities intended for text-to-speech synthesis. A `.vox` file captures everything needed to reproduce a consistent voice across TTS engines: descriptive metadata, reference audio, transcripts, prosodic preferences, and optional engine-specific embeddings.

No such standard exists today. Every TTS system — Apple's proprietary `.SpeechVoice` bundles, ElevenLabs' server-side voice IDs, Qwen3-TTS's in-memory tensor prompts, OpenAI's named preset strings — stores voice identity in an incompatible, non-portable way. VOX fills this gap.

## Motivation

### The Screenplay Production Pipeline

The immediate use case is the **intrusive-memory** screenplay-to-audio pipeline:

1. **[SwiftEchada](https://github.com/intrusive-memory/SwiftEchada)** extracts characters from Fountain screenplays using on-device LLM inference and matches them to TTS voices. Today, Echada produces voice URIs like `apple://en/Aaron` or `elevenlabs://en/vid-abc` — opaque handles tied to a specific provider.

2. **[SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta)** uses Qwen3-TTS on Apple Silicon to design voices from character descriptions, lock voice identities via clone prompts, and render dialogue audio. VoxAlta can create rich voice identities — but has no way to persist them beyond runtime.

The gap: when Echada casts a character and VoxAlta designs a voice for them, that voice exists only as an ephemeral Python/Swift object. If the model is reloaded, the session ends, or the user switches to a different TTS engine, the voice is gone. The user must re-design or re-clone from scratch.

A `.vox` file is the **headshot and voice reel** that bridges casting (Echada) and performance (VoxAlta or any provider).

### The Broader Problem

This isn't unique to our pipeline. Consider:

- A **podcast producer** designs a narrator voice in ElevenLabs, then wants to switch to a local model for cost reasons. No way to transfer the voice identity.
- A **game studio** defines 40 character voices during pre-production. Voice actors change, TTS engines change, but the *voice specifications* should be stable artifacts that any engine can consume.
- A **screenwriter** iterates on character voices across multiple tools — designing in Qwen3-TTS, previewing in Apple TTS, rendering final in ElevenLabs. Each transition currently means starting over.
- An **accessibility tool** lets a user define their preferred reading voice. That preference should travel with them across devices and platforms.

## Design Principles

1. **Vendor-neutral** — No engine-specific data is required. Any TTS system that can accept a text description or a reference audio clip can consume a `.vox` file.
2. **Progressively detailed** — A minimal `.vox` needs only a name and a text description. Richer files can include reference audio, transcripts, prosodic profiles, and engine-specific embeddings.
3. **Human-readable manifest** — The core metadata is JSON, inspectable without special tooling.
4. **Self-contained** — A `.vox` file bundles all referenced assets (audio, embeddings) so it can be copied, versioned, and shared as a single artifact.
5. **Extensible** — Engine-specific data lives in namespaced extension slots that conforming readers can safely ignore.
6. **Screenplay-aware** — First-class support for character context: role descriptions, emotional range, relationship to narrative.

## Format Specification

### Container Structure

A `.vox` file is a **ZIP archive** with the extension `.vox`. This follows the precedent of `.docx`, `.epub`, `.ipa`, and other modern container formats.

```
character.vox
├── manifest.json          # Required. Voice identity metadata.
├── reference/             # Optional. Reference audio files.
│   ├── sample-01.wav
│   ├── sample-02.wav
│   └── ...
├── embeddings/            # Optional. Engine-specific data.
│   ├── qwen3-tts/
│   │   └── clone-prompt.bin
│   ├── elevenlabs/
│   │   └── voice-id.json
│   └── ...
└── assets/                # Optional. Additional assets.
    └── headshot.png        # Character reference image, etc.
```

### manifest.json

The manifest is the only required file. It must be valid JSON encoded as UTF-8.

```json
{
  "vox_version": "0.1.0",
  "id": "uuid-v4-here",
  "created": "2026-02-13T00:00:00Z",
  "modified": "2026-02-13T00:00:00Z",

  "voice": {
    "name": "LAZARILLO",
    "description": "Male, late teens, Spanish. Bright tenor voice with a street-smart edge. Quick-witted delivery, shifts easily between earnest sincerity and sly irony. Castilian accent with lower-class markers.",
    "language": "es",
    "gender": "male",
    "age_range": [16, 19],
    "tags": ["tenor", "youthful", "ironic", "picaresque"]
  },

  "prosody": {
    "pitch_base": "medium-high",
    "pitch_range": "wide",
    "rate": "medium-fast",
    "energy": "medium-high",
    "emotion_default": "wry amusement"
  },

  "reference_audio": [
    {
      "file": "reference/sample-01.wav",
      "transcript": "Pues sepa vuestra merced, ante todas cosas, que a mí llaman Lázaro de Tormes.",
      "language": "es",
      "duration_seconds": 4.2,
      "context": "Opening narration. Sardonic, world-weary but youthful."
    }
  ],

  "character": {
    "role": "Protagonist and narrator. A young boy surviving by his wits through service to various masters in 16th-century Spain.",
    "emotional_range": ["sardonic", "fearful", "hungry", "defiant", "tender"],
    "relationships": {
      "THE BLIND MAN": "First master. Fear mixed with grudging respect.",
      "THE SQUIRE": "Third master. Pity and unexpected affection."
    },
    "source": {
      "work": "Lazarillo de Tormes",
      "format": "fountain",
      "file": "episodes/lazarillo-tratado-01.fountain"
    }
  },

  "provenance": {
    "method": "designed",
    "engine": "qwen3-tts-voicedesign-1.7b",
    "consent": null,
    "license": "CC0-1.0",
    "notes": "Voice designed from character description, not cloned from a real person."
  },

  "extensions": {
    "qwen3-tts": {
      "model": "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
      "clone_prompt": "embeddings/qwen3-tts/clone-prompt.bin",
      "design_instruct": "Voz masculina juvenil con tono pícaro y astuto, acento castellano popular del siglo XVI, tenor brillante con matices irónicos."
    },
    "apple": {
      "voice_id": "es/Jorge",
      "fallback": true
    },
    "elevenlabs": {
      "voice_id": "vid-abc123",
      "model_id": "eleven_multilingual_v2"
    }
  }
}
```

### Field Definitions

#### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `vox_version` | string | Semver version of the VOX format spec. |
| `id` | string | UUID v4 uniquely identifying this voice. |
| `created` | string | ISO 8601 creation timestamp. |
| `voice.name` | string | Display name for the voice. UPPERCASE for screenplay characters. |
| `voice.description` | string | Natural-language description of the voice. This is the universal input that any voice-design-capable TTS can consume directly. |

#### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `voice.language` | string | BCP 47 primary language code. |
| `voice.gender` | string | `male`, `female`, `nonbinary`, `neutral`. |
| `voice.age_range` | [int, int] | Approximate age range `[min, max]`. |
| `voice.tags` | [string] | Freeform descriptive tags for search/filtering. |
| `prosody.*` | object | Default prosodic profile. Values are descriptive strings, not numeric — engines interpret them according to their own scales. |
| `reference_audio` | [object] | Array of reference clips with transcripts. |
| `character` | object | Screenplay/narrative context. |
| `provenance` | object | How the voice was created, consent status, licensing. |
| `extensions` | object | Namespaced engine-specific data. Keys are provider identifiers. |

### Reference Audio Requirements

- Format: WAV (PCM 16-bit or 24-bit) or FLAC. MP3 is discouraged due to lossy compression artifacts that degrade clone quality.
- Sample rate: 16kHz minimum, 24kHz or 44.1kHz preferred.
- Duration: 3–30 seconds per clip. Most clone engines need at least 3 seconds.
- Transcript is strongly recommended — required by most clone systems (Qwen3-TTS, Coqui XTTS) for full-quality cloning; only x-vector-only modes can skip it.

### Extension Namespaces

Extensions are keyed by provider identifier. Conforming readers MUST ignore extensions they don't recognize. Extension data may reference files in the `embeddings/` directory.

Reserved provider identifiers:

| Key | Provider |
|-----|----------|
| `qwen3-tts` | Qwen3-TTS (Alibaba) |
| `apple` | Apple AVSpeechSynthesis / macOS TTS |
| `elevenlabs` | ElevenLabs |
| `openai` | OpenAI TTS |
| `coqui` | Coqui TTS / XTTS |
| `parler` | Parler-TTS |
| `google` | Google Cloud TTS |
| `azure` | Microsoft Azure Speech |
| `mlx-audio` | MLX Audio (Apple Silicon) |

### Embedding Metadata (v0.2.0)

The optional `embeddings` top-level object provides structured metadata about model-specific binary embeddings stored in the archive. This enables a single `.vox` file to carry embeddings for multiple model variants (e.g., a lightweight 0.6B model and a full-quality 1.7B model).

Each key is a human-readable identifier, and the value describes the model that produced the embedding, the file path within the archive, and optional hints.

```json
"embeddings": {
  "qwen3-tts-0.6b": {
    "model": "Qwen/Qwen3-TTS-12Hz-0.6B",
    "engine": "qwen3-tts",
    "file": "embeddings/qwen3-tts/0.6b/clone-prompt.bin",
    "format": "bin",
    "description": "Clone prompt for lightweight 0.6B model"
  },
  "qwen3-tts-1.7b": {
    "model": "Qwen/Qwen3-TTS-12Hz-1.7B",
    "engine": "qwen3-tts",
    "file": "embeddings/qwen3-tts/1.7b/clone-prompt.bin",
    "format": "bin",
    "description": "Clone prompt for full-quality 1.7B model"
  }
}
```

#### Embedding Entry Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `model` | Yes | string | Fully qualified model identifier (e.g., `"Qwen/Qwen3-TTS-12Hz-0.6B"`). |
| `file` | Yes | string | Archive-relative path to the binary. Must start with `embeddings/`. |
| `engine` | No | string | Engine namespace (e.g., `"qwen3-tts"`). Links to the `extensions` section. |
| `format` | No | string | Binary format hint: `"bin"`, `"safetensors"`, `"onnx"`, etc. |
| `description` | No | string | Human-readable note about this embedding. |

#### Directory Structure for Multi-Model Embeddings

```
embeddings/
  qwen3-tts/
    0.6b/
      clone-prompt.bin      ← per-variant subdirectory
    1.7b/
      clone-prompt.bin
```

#### Consumer API

Implementations should provide query methods for model support:

- `supportsModel("0.6b")` → `true` (substring match on key or model)
- `supportsModel("Qwen/Qwen3-TTS-12Hz-1.7B")` → `true` (exact model match)
- `supportedModels` → `["Qwen/Qwen3-TTS-12Hz-0.6B", "Qwen/Qwen3-TTS-12Hz-1.7B"]`
- `embeddingData(for: "0.6b")` → binary `Data` for the 0.6B clone prompt

The `embeddings` section is optional. Files without it remain valid — backward compatibility with v0.1.0 is preserved.

### Provenance

The `provenance` object tracks how the voice was created:

| `method` value | Meaning |
|----------------|---------|
| `designed` | Generated from a text description (no real person). |
| `cloned` | Cloned from a real person's audio. |
| `preset` | Based on a vendor's built-in voice. |
| `hybrid` | Designed, then refined with reference audio. |

The `consent` field:
- `null` — Not applicable (synthetic/designed voice).
- `"self"` — The file creator is the voice owner.
- `"granted"` — Explicit consent obtained from the voice owner.
- `"unknown"` — Consent status unclear.

## Integration with SwiftEchada

### Current Flow

```
Fountain screenplay
    → [echada extract] → Cast list in PROJECT.md
    → [echada match]   → Voice URIs (apple://en/Aaron)
    → [VoxAlta]        → Audio (ephemeral voice identity)
```

### Proposed Flow with VOX

```
Fountain screenplay
    → [echada extract]  → Cast list in PROJECT.md
    → [echada cast]     → .vox files per character (in project voices/ directory)
    → [VoxAlta]         → Reads .vox, creates/caches clone prompt, renders audio
    → [any provider]    → Reads same .vox, uses description + ref audio
```

### New Echada Command: `echada cast`

Building on the existing `extract` and `match` commands, a new `cast` command would:

1. Read the cast list from PROJECT.md.
2. For each character, generate a voice description using LLM inference based on character evidence (dialogue samples, stage directions, genre context).
3. Optionally invoke VoxAlta to run VoiceDesign, producing a reference audio clip.
4. Package everything into a `.vox` file and write it to `<project>/voices/<CHARACTER>.vox`.
5. Update PROJECT.md cast entries with the `.vox` file paths.

```bash
# Full cast creation: extract characters, design voices, produce .vox files
echada cast --project PROJECT.md --provider qwen3-tts --language es

# Design a single character's voice
echada cast --project PROJECT.md --character LAZARILLO --provider qwen3-tts

# Re-cast with a different engine, preserving existing .vox metadata
echada cast --project PROJECT.md --provider elevenlabs --augment
```

The `--augment` flag adds a new engine extension to existing `.vox` files rather than replacing them — the same accumulation pattern Echada already uses for multi-provider voice URIs.

### VoxAlta Consumption

VoxAlta would gain a `loadVoice(_ voxFile: URL)` method:

```swift
let provider = VoxAltaProvider()

// Load a .vox file — extracts clone prompt if cached in extensions,
// otherwise creates one from reference audio
let voice = try await provider.loadVoice(projectDir.appending("voices/LAZARILLO.vox"))

// Synthesize dialogue using the loaded voice identity
let audio = try await provider.synthesize(
    text: "Pues sepa vuestra merced...",
    voice: voice
)
```

If the `.vox` file contains a cached `qwen3-tts` clone prompt in its extensions, VoxAlta loads it directly. If not, it reads the reference audio and transcript, runs `create_voice_clone_prompt`, and optionally writes the result back into the `.vox` for future use.

### PROJECT.md Integration

Cast entries in PROJECT.md would reference `.vox` files alongside (or instead of) voice URIs:

```yaml
cast:
  - name: LAZARILLO
    description: "Young boy, protagonist, sardonic narrator"
    vox: voices/LAZARILLO.vox
    voices:
      - apple://es/Jorge
      - elevenlabs://es/vid-abc123
      - qwen3-tts://designed/lazarillo-v2
```

The `vox` field is the canonical voice identity. The `voices` array becomes a compatibility/fallback list derived from the `.vox` extensions.

## Relationship to Existing Standards

| Standard | What it covers | What VOX adds |
|----------|---------------|---------------|
| **SSML** (W3C) | How to *say* text: prosody, pauses, pronunciation, emphasis. Selects voices by name/gender from engine catalog. | *Who* is speaking: persistent voice identity, reference audio, character context. |
| **VoiceXML** (W3C) | Interactive voice response systems. | VOX is for voice *identity*, not dialogue flow. |
| **`.SpeechVoice`** (Apple) | Proprietary macOS voice bundles. | Open, cross-platform, human-readable. |
| **Speaker embeddings** (x-vector, d-vector) | Numeric voice fingerprints for a specific model architecture. | Model-agnostic container that *includes* embeddings as optional extensions alongside universal representations. |

VOX is complementary to SSML, not a replacement. A production pipeline might use `.vox` files to define *who* speaks, and SSML to control *how* they speak.

## Open Questions

1. **Embedding portability** — Should the spec define any standard embedding format (e.g., a fixed-dimension d-vector), or rely entirely on reference audio as the universal interchange and treat all embeddings as opaque engine extensions?

2. **Voice versioning** — When a voice is refined over time (re-designed, re-cloned with better audio), should `.vox` files support internal version history, or is file-level versioning (git, filesystem) sufficient?

3. **Multi-voice files** — Should a single `.vox` contain multiple voices (e.g., an entire cast), or should each voice be its own file? Current design favors one-voice-per-file for simplicity and composability.

4. **Streaming / partial load** — For large files with multiple reference clips, should the spec mandate any particular ordering to support streaming reads?

5. **Spec governance** — Where should the canonical spec live? Options: standalone repo (`vox-format/spec`), within SwiftEchada, or within SwiftHablare (the shared voice provider layer).

## File Type Registration

- **Extension:** `.vox`
- **MIME type:** `application/vnd.vox+zip` (proposed)
- **UTI:** `com.intrusive-memory.vox` (proposed, for macOS/iOS)

Note: `.vox` is historically associated with Dialogic ADPCM telephony audio. The VOX voice identity format is unrelated but the collision risk is low — Dialogic VOX is a raw audio codec from the 1990s with no container structure, no magic bytes, and negligible modern usage. The ZIP magic bytes (`PK\x03\x04`) at offset 0 disambiguate unambiguously.

## License

This specification is released under [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) — public domain, no rights reserved. Implementations may use any license.
