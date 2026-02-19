# VOX Format - Shared Agent Context

**Purpose:** This file contains shared context and decisions that apply to ALL AI agents working on the VOX format project. When you learn something important about the project, patterns, or decisions, update this file so all agents benefit from the knowledge.

---

## Project Overview

VOX (`.vox`) is an open, vendor-neutral file format for persisting voice identities for text-to-speech synthesis. It captures everything needed to reproduce a consistent voice across TTS engines: descriptive metadata, reference audio, transcripts, prosodic preferences, and optional engine-specific embeddings.

**Key Repository Links:**
- Specification: [`docs/VOX-FORMAT.md`](docs/VOX-FORMAT.md)
- Main Repository: https://github.com/intrusive-memory/vox-format

**Related Projects:**
- [SwiftEchada](https://github.com/intrusive-memory/SwiftEchada) - Screenplay character extraction and voice casting
- [SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta) - Qwen3-TTS voice design and synthesis on Apple Silicon
- [SwiftHablare](https://github.com/intrusive-memory/SwiftHablare) - Shared voice provider abstraction layer

---

## Design Principles

1. **Vendor-neutral** — No engine-specific data is required. Any TTS system can consume a `.vox` file.
2. **Progressively detailed** — Minimal `.vox` needs only name + description. Richer files can include audio, transcripts, prosody, embeddings.
3. **Human-readable manifest** — Core metadata is JSON, inspectable without special tooling.
4. **Self-contained** — A `.vox` file bundles all referenced assets as a single ZIP archive.
5. **Extensible** — Engine-specific data lives in namespaced extension slots.
6. **Screenplay-aware** — First-class support for character context: role descriptions, emotional range, relationships.

---

## Architecture Decisions

### Container Format

- **Decision:** Use ZIP archive with `.vox` extension
- **Rationale:** Follows precedent of `.docx`, `.epub`, `.ipa`. Self-contained, broadly supported, human-inspectable with standard tools.
- **Disambiguation:** Historical `.vox` (Dialogic ADPCM) is unrelated and unambiguous (no ZIP magic bytes).

### Manifest Structure

- **Decision:** Single required `manifest.json` file, UTF-8 encoded
- **Required Fields:** `vox_version`, `id` (UUID v4), `created` (ISO 8601), `voice.name`, `voice.description`
- **Optional but Important:** `reference_audio[]`, `prosody`, `character`, `provenance`, `extensions`

### Reference Audio

- **Preferred Formats:** WAV (PCM 16/24-bit) or FLAC. Avoid MP3 (lossy artifacts).
- **Sample Rate:** 16kHz minimum, 24kHz or 44.1kHz preferred
- **Duration:** 3–30 seconds per clip
- **Transcript:** Strongly recommended (required by Qwen3-TTS, Coqui XTTS for full-quality cloning)

### Extension Namespaces

Reserved provider identifiers: `qwen3-tts`, `apple`, `elevenlabs`, `openai`, `coqui`, `parler`, `google`, `azure`, `mlx-audio`

Conforming readers MUST ignore unknown extensions.

---

## Implementation Status

### Current State (v0.1.0)

- ✅ Specification drafted (v0.1.0)
- ✅ JSON Schema validation (`schemas/manifest-v0.1.0.json`)
- ✅ Swift reference implementation (`implementations/swift/`)
  - `VoxManifest` — Codable manifest model with snake_case JSON mapping
  - `VoxFile` — In-memory container (manifest + reference audio + embeddings)
  - `VoxReader` — Reads `.vox` ZIP archives directly into memory
  - `VoxWriter` — Creates `.vox` ZIP archives from `VoxFile` instances
  - `VoxValidator` — Validates manifests (permissive + strict modes)
  - `VoxError` — Typed error hierarchy for all failure cases
- ✅ CLI tool (`tools/vox-cli/`) — inspect, validate, create, extract commands
- ✅ Example `.vox` files (`examples/`) — minimal, character, multi-engine, voice library
- ✅ CI/CD — GitHub Actions with Swift tests + JSON Schema validation
- ✅ SPM support — Root-level `Package.swift` for URL-based dependencies
- ⏳ SwiftEchada integration (`echada cast` command)
- ⏳ SwiftVoxAlta `.vox` loader

### Integration Roadmap

1. **SwiftEchada:** Add `echada cast` command to generate `.vox` files from screenplay character analysis
2. **SwiftVoxAlta:** Add `loadVoice(_ voxFile: URL)` method to consume `.vox` files
3. **PROJECT.md:** Add `vox:` field to cast entries

---

## Common Patterns

### Swift: Reading a VOX File

```swift
import VoxFormat

let reader = VoxReader()
let voxFile = try reader.read(from: URL(fileURLWithPath: "voice.vox"))
print(voxFile.manifest.voice.name)        // "NARRATOR"
print(voxFile.manifest.voice.description)  // "A warm narrator voice..."

// Access reference audio
for (filename, data) in voxFile.referenceAudio {
    print("\(filename): \(data.count) bytes")
}

// Access engine-specific embeddings
if let prompt = voxFile.embeddings["qwen3-tts/clone-prompt.bin"] {
    print("Clone prompt: \(prompt.count) bytes")
}
```

### Swift: Creating a VOX File

```swift
import VoxFormat

let manifest = VoxManifest(
    voxVersion: "0.1.0",
    id: UUID().uuidString.lowercased(),
    created: Date(),
    voice: VoxManifest.Voice(
        name: "NARRATOR",
        description: "A warm, clear narrator voice for audiobooks."
    )
)
let voxFile = VoxFile(manifest: manifest)
let writer = VoxWriter()
try writer.write(voxFile, to: URL(fileURLWithPath: "narrator.vox"))
```

### Swift: Validating a Manifest

```swift
import VoxFormat

let validator = VoxValidator()
try validator.validate(voxFile.manifest)           // permissive (collects all errors)
try validator.validate(voxFile.manifest, strict: true)  // strict (fails on first error)
```

### Creating a Minimal VOX File (JSON)

```json
{
  "vox_version": "0.1.0",
  "id": "uuid-here",
  "created": "2026-02-13T00:00:00Z",
  "voice": {
    "name": "CHARACTER_NAME",
    "description": "Natural language voice description..."
  }
}
```

### Adding Engine Extensions

When multiple engines support the same voice:
- Keep universal fields in root `voice` object
- Add engine-specific data to `extensions.<provider>`
- Use `--augment` pattern to add extensions without replacing existing ones

### Key Implementation Notes

- **In-memory model:** `VoxFile` holds all data in memory (no temp files). Binary assets are `Data` values in dictionaries.
- **JSON key mapping:** Swift properties use camelCase, JSON uses snake_case (handled via `CodingKeys`).
- **ZIP format:** Uses ZIPFoundation library. Archives verified by checking `PK\x03\x04` magic bytes after write.
- **Date handling:** ISO 8601 encoding/decoding via `VoxManifest.encoder()` and `VoxManifest.decoder()`.
- **Extensions:** Arbitrary JSON in `extensions` dictionary uses `AnyCodable` type-erased wrapper.

---

## Open Questions

1. **Embedding portability:** Standard embedding format (fixed d-vector) vs. opaque engine extensions?
2. **Voice versioning:** Internal version history in `.vox` or file-level versioning (git)?
3. **Multi-voice files:** Single `.vox` for entire cast or one-voice-per-file?
4. **Streaming / partial load:** Ordering requirements for large files with multiple reference clips?
5. **Spec governance:** Where should canonical spec live? Options: standalone repo (current), SwiftEchada, SwiftHablare

---

## File Type Registration

- **Extension:** `.vox`
- **MIME type:** `application/vnd.vox+zip` (proposed)
- **UTI:** `com.intrusive-memory.vox` (proposed, for macOS/iOS)

---

## Contributing Guidelines

When updating this file:
- **Add, don't delete:** Preserve historical decisions with strikethrough if superseded
- **Date important decisions:** Use ISO 8601 format (YYYY-MM-DD)
- **Link to issues/PRs:** Reference GitHub issues for context when applicable
- **Keep concise:** This is shared context, not exhaustive documentation
- **Organize semantically:** Group by topic, not chronologically

---

## Agent-Specific Notes

### For Claude Agents
- See `CLAUDE.md` for Claude-specific instructions
- Update THIS file (AGENTS.md) for shared context
- Update CLAUDE.md only for Claude-specific workflow preferences

### For Gemini Agents
- See `GEMINI.md` for Gemini-specific instructions
- Update THIS file (AGENTS.md) for shared context
- Update GEMINI.md only for Gemini-specific workflow preferences

---

**Last Updated:** 2026-02-18
