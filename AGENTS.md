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

### Current State (v0.2.0)

- ✅ Specification drafted (v0.2.0 — adds multi-model embedding metadata)
- ✅ JSON Schema validation (`schemas/manifest-v0.1.0.json`)
- ✅ Swift reference implementation (`implementations/swift/`) — **container-first API**
  - `VoxFile` — The primary API. A mutable class that holds manifest + entries. Handles I/O (`init(contentsOf:)`, `write(to:)`), validation (`validate()`, `isValid`), model queries (`supportsModel()`, `embeddingData(for:)`), and entry management (`add()`, `remove()`, subscript).
  - `VoxEntry` — An archive entry carrying `path`, `data`, `mimeType`, and `metadata`.
  - `VoxManifest` — Codable manifest model with snake_case JSON mapping.
  - `VoxMigrator` — Internal; auto-migrates v0.1.0 manifests on read.
  - `VoxError` — Typed error hierarchy for all failure cases.
  - `VoxIssue` — Validation finding with `severity` (info/warning/error), `message`, and optional `field`.
- ✅ CLI tool (`tools/vox-cli/`) — inspect, validate, create, extract commands
- ✅ Example `.vox` files (`examples/`) — minimal, character, multi-engine, voice library
- ✅ CI/CD — GitHub Actions with Swift tests + JSON Schema validation
- ✅ SPM support — Root-level `Package.swift` for URL-based dependencies
- ⏳ SwiftEchada integration (`echada cast` command)
- ⏳ SwiftVoxAlta `.vox` loader

### API Design (2026-02-21)

**Decision:** Adopted a container-first architecture where `VoxFile` is the sole public API surface. Previous separate types (`VoxReader`, `VoxWriter`, `VoxValidator`, `VoxModelQueryable`) were deleted; their functionality is now methods on `VoxFile`.

**Rationale:** The mental model is simpler — a `.vox` file is a container. You put things in, take them out, query them, and validate. No need to instantiate separate reader/writer/validator objects.

**Key behaviors:**
- `VoxFile` is a **class** (reference semantics for large binary data).
- `add()` at `reference/` prefix auto-creates `manifest.referenceAudio` entries from metadata keys (`transcript`, `language`, `duration_seconds`).
- `add()` at `embeddings/` prefix auto-creates `manifest.embeddingEntries` entries from metadata keys (`model` required, `engine`, `format`, `description`, `key`).
- `remove()` auto-removes corresponding manifest entries.
- `validate()` returns `[VoxIssue]` instead of throwing, so callers can inspect all problems at once.
- `init(contentsOf:)` auto-migrates old v0.1.0 manifests to current version.

### Integration Roadmap

1. **SwiftEchada:** Add `echada cast` command to generate `.vox` files from screenplay character analysis
2. **SwiftVoxAlta:** Add `loadVoice(_ voxFile: URL)` method to consume `.vox` files
3. **PROJECT.md:** Add `vox:` field to cast entries

---

## Common Patterns

### Swift: Reading a VOX File

```swift
import VoxFormat

let vox = try VoxFile(contentsOf: URL(fileURLWithPath: "voice.vox"))
print(vox.manifest.voice.name)        // "NARRATOR"
print(vox.manifest.voice.description)  // "A warm narrator voice..."

// Access reference audio
for entry in vox.entries(under: "reference/") {
    print("\(entry.path): \(entry.data.count) bytes, \(entry.mimeType)")
}

// Access engine-specific embeddings
if let entry = vox["embeddings/qwen3-tts/0.6b/clone-prompt.bin"] {
    print("Clone prompt: \(entry.data.count) bytes")
}

// Query model support
if vox.supportsModel("qwen3-tts-0.6b") {
    let data = vox.embeddingData(for: "0.6b")
}
print(vox.supportedModels)  // ["Qwen/Qwen3-TTS-12Hz-0.6B", ...]
```

### Swift: Creating a VOX File

```swift
import VoxFormat

let vox = VoxFile(name: "NARRATOR", description: "A warm, clear narrator voice for audiobooks.")

// Add reference audio (auto-updates manifest.referenceAudio)
try vox.add(audioData, at: "reference/sample.wav", metadata: [
    "transcript": "Hello, welcome to the audiobook.",
    "language": "en-US",
    "duration_seconds": 3.5
])

// Add embeddings (auto-updates manifest.embeddingEntries)
try vox.add(embeddingData, at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
    "model": "Qwen/Qwen3-TTS-12Hz-0.6B",
    "engine": "qwen3-tts"
])

try vox.write(to: URL(fileURLWithPath: "narrator.vox"))
```

### Swift: Validating

```swift
import VoxFormat

let issues = vox.validate()  // returns [VoxIssue]
let errors = issues.filter { $0.severity == .error }
let warnings = issues.filter { $0.severity == .warning }
print(vox.isValid)      // true if no errors
print(vox.readiness)    // .ready, .needsRegeneration(missing:), or .invalid(reasons:)
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

- **In-memory model:** `VoxFile` holds all data in memory (no temp files). Internal storage is `[String: VoxEntry]` keyed by archive path.
- **Auto-manifest:** `add()` and `remove()` automatically keep `manifest.referenceAudio` and `manifest.embeddingEntries` in sync. Callers never manage these arrays directly.
- **MIME detection:** `VoxMIME.mimeType(forExtension:)` maps `.wav` -> `audio/wav`, `.bin` -> `application/octet-stream`, etc.
- **JSON key mapping:** Swift properties use camelCase, JSON uses snake_case (handled via `CodingKeys`).
- **ZIP format:** Uses ZIPFoundation library. Archives verified by checking `PK\x03\x04` magic bytes after write.
- **Date handling:** ISO 8601 encoding/decoding via `VoxManifest.encoder()` and `VoxManifest.decoder()`.
- **Extensions:** Arbitrary JSON in `extensions` dictionary uses `AnyCodable` type-erased wrapper.

### Multi-Model Embedding Support (v0.2.0, 2026-02-21)

**Decision:** Added a structured `embeddings` top-level section to `manifest.json` that maps identifiers to model/file metadata. This is separate from the opaque `extensions` section.

**Rationale:** Different model variants (e.g., 0.6B vs 1.7B) produce incompatible binary embeddings. The same voice needs to carry embeddings for multiple models. Storing this as first-class typed data (not buried in `extensions`) enables consumer APIs to query model support without knowing engine internals.

**Key Types:**
- `VoxManifest.EmbeddingEntry` — Codable struct with `model` (required), `file` (required), `engine`, `format`, `description`
- Model query methods (`supportsModel()`, `embeddingEntry(for:)`, `embeddingData(for:)`, `supportedModels`) live directly on `VoxFile`

**Matching Strategy:** `supportsModel()` uses cascading match: exact key → case-insensitive key → case-insensitive model contains → case-insensitive key contains.

**Archive Layout:**
```
embeddings/
  qwen3-tts/
    0.6b/clone-prompt.bin
    1.7b/clone-prompt.bin
```

**Backward Compatibility:** The `embeddings` manifest section is optional. Old `.vox` files (v0.1.0) without it parse without error. `VoxMigrator` auto-migrates on read.

---

## Open Questions

1. **~~Embedding portability~~** — Resolved (v0.2.0): Structured `embeddings` manifest section provides model-aware metadata while keeping binary formats opaque. No standard d-vector format imposed.
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

**Last Updated:** 2026-02-21
