<p align="center">
  <img src="vox-format.jpg" alt="VOX Format Logo" width="400">
</p>

# VOX: Open Voice Identity Format

![Swift Tests](https://github.com/intrusive-memory/vox-format/actions/workflows/swift-tests.yml/badge.svg)

**Version:** 0.2.0
**License:** [CC0 1.0 Universal](LICENSE) (Public Domain)

VOX (`.vox`) is an open, vendor-neutral file format for persisting voice identities for text-to-speech synthesis. Think of it as a **headshot and voice reel** for AI voices — capturing everything needed to reproduce a consistent voice across different TTS engines.

---

## The Problem

Every TTS system stores voice identity differently:
- Apple's proprietary `.SpeechVoice` bundles
- ElevenLabs' server-side voice IDs
- Qwen3-TTS's in-memory tensor prompts
- OpenAI's named preset strings

If you design a character voice in one system, there's no standard way to transfer it to another. No portability. No persistence. No archiving.

## The Solution

A `.vox` file is a **self-contained ZIP archive** with a JSON manifest that bundles:
- 📝 Voice description (natural language, works with any TTS)
- 🎤 Reference audio clips with transcripts
- 🎭 Character context (for screenplay/narrative work)
- 🎛️ Prosody preferences (pitch, rate, energy)
- 🔌 Engine-specific embeddings (optional, namespaced)

```
character.vox (ZIP archive)
├── manifest.json          # Voice metadata
├── reference/             # Audio samples
│   ├── sample-01.wav
│   └── sample-02.wav
├── embeddings/            # Engine-specific data
│   ├── qwen3-tts/
│   └── elevenlabs/
└── assets/                # Headshot, etc.
    └── headshot.png
```

---

## Features

### ✅ Vendor-Neutral
No engine-specific data is required. Any TTS that accepts text descriptions or reference audio can use a `.vox` file.

### ✅ Progressively Detailed
Start minimal (name + description), add richness over time (audio, transcripts, prosody, embeddings).

### ✅ Human-Readable
Core metadata is JSON. Inspect with any text editor or standard tools.

### ✅ Self-Contained
All assets bundled in one file. Easy to version, share, archive.

### ✅ Screenplay-Aware
First-class support for character context: role descriptions, emotional range, relationships to other characters.

### ✅ Ethically Conscious
Built-in provenance tracking: how was the voice created? Who owns it? Was consent granted?

---

## Example: Minimal VOX File

The simplest valid `.vox` file needs only a name and description:

```json
{
  "vox_version": "0.1.0",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "created": "2026-02-13T12:00:00Z",
  "voice": {
    "name": "NARRATOR",
    "description": "Male, middle-aged, warm and authoritative. Deep baritone with clear enunciation, paced for audiobook narration."
  }
}
```

This description alone works with voice-design-capable engines like Qwen3-TTS, Parler-TTS, or ElevenLabs text-to-voice.

For richer voices, add reference audio, character context, and engine extensions. See [`docs/VOX-FORMAT.md`](docs/VOX-FORMAT.md) for the complete specification.

---

## Use Cases

### 🎬 Screenplay Production
- **[SwiftEchada](https://github.com/intrusive-memory/SwiftEchada)** extracts characters from Fountain screenplays and generates `.vox` files for each character
- **[SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta)** loads `.vox` files and renders dialogue audio with Qwen3-TTS
- Switch TTS engines without re-designing voices

### 🎙️ Podcast Production
- Design narrator and guest voices once
- Switch between preview (fast, local) and production (high-quality, cloud) TTS engines
- Archive voice configurations with your project

### 🎮 Game Development
- Define 40 character voices during pre-production
- Voice actors change, TTS engines change, but voice *specifications* stay stable
- Share voice profiles across dev, QA, and localization teams

### 📖 Accessibility Tools
- User defines their preferred reading voice once
- Voice travels with them across devices and platforms
- No vendor lock-in

---

## Specification

See **[`docs/VOX-FORMAT.md`](docs/VOX-FORMAT.md)** for the complete technical specification.

Key sections:
- Container structure (ZIP archive)
- Manifest schema (JSON)
- Reference audio requirements
- Extension namespaces for engine-specific data
- Provenance and consent tracking
- Integration with SwiftEchada and SwiftVoxAlta

---

## Swift Package Manager

Add VoxFormat as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/vox-format.git", from: "0.1.0"),
]
```

Then add `VoxFormat` to your target's dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "VoxFormat", package: "vox-format"),
    ]
)
```

**Platform requirements:** macOS 13+, iOS 16+, Swift 6.2+

## Quick Start (Swift)

```swift
import VoxFormat

// Read a .vox file
let vox = try VoxFile(contentsOf: URL(fileURLWithPath: "voice.vox"))
print(vox.manifest.voice.name)

// Create a .vox file
let vox = VoxFile(name: "NARRATOR", description: "A warm, clear narrator voice for audiobooks.")
try vox.write(to: URL(fileURLWithPath: "narrator.vox"))

// Add reference audio
try vox.add(audioData, at: "reference/sample.wav", metadata: [
    "transcript": "Hello, welcome to the audiobook.",
    "language": "en-US",
    "duration_seconds": 3.5
])

// Add engine-specific embeddings
try vox.add(embeddingData, at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
    "model": "Qwen/Qwen3-TTS-12Hz-0.6B",
    "engine": "qwen3-tts"
])

// Query model support
if vox.supportsModel("qwen3-tts-0.6b") {
    let data = vox.embeddingData(for: "0.6b")
}

// Validate
let issues = vox.validate()
print(vox.isValid)  // true if no errors
```

## CLI Tool

A command-line tool is included for working with `.vox` files:

```bash
# Inspect a .vox file
vox-cli inspect voice.vox

# Validate a .vox file
vox-cli validate voice.vox

# Create a .vox file
vox-cli create --name "NARRATOR" --description "A warm narrator voice..." output.vox

# Extract a .vox archive
vox-cli extract voice.vox --output ./extracted/
```

See [`tools/vox-cli/`](tools/vox-cli/) for build instructions.

## Roadmap

### Shipped (v0.2.0)
- ✅ Specification drafted
- ✅ JSON Schema for automated validation
- ✅ Swift reference implementation — container-first API (`VoxFile` is the API)
- ✅ Multi-model embedding support with structured manifest metadata
- ✅ CLI tool (inspect, validate, create, extract)
- ✅ Example `.vox` files (minimal, character, multi-engine, voice library)
- ✅ CI/CD with GitHub Actions (Swift tests + schema validation)
- ✅ Swift Package Manager support (URL-based dependency)

### Planned
- ⏳ SwiftEchada integration (`echada cast` command)
- ⏳ SwiftVoxAlta `.vox` loader

---

## File Type Registration

- **Extension:** `.vox`
- **MIME type:** `application/vnd.vox+zip` (proposed)
- **UTI:** `com.intrusive-memory.vox` (proposed, for macOS/iOS)

**Note on collision:** The `.vox` extension is historically associated with Dialogic ADPCM telephony audio (1990s codec). The VOX voice identity format is unrelated but unambiguous — ZIP archives start with `PK\x03\x04` magic bytes, Dialogic VOX files do not.

---

## Related Projects

Part of the **intrusive-memory** ecosystem:

- **[SwiftEchada](https://github.com/intrusive-memory/SwiftEchada)** — Screenplay character extraction and voice casting
- **[SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta)** — Qwen3-TTS voice design and synthesis on Apple Silicon
- **[SwiftHablare](https://github.com/intrusive-memory/SwiftHablare)** — Shared voice provider abstraction layer

---

## Contributing

This is an open specification under CC0 (public domain). Contributions welcome:

- **Specification improvements:** Open an issue or PR on [`docs/VOX-FORMAT.md`](docs/VOX-FORMAT.md)
- **Swift implementation:** Contribute to `implementations/swift/` (this is a Swift-only project)
- **Example files:** Add to `examples/` with documentation
- **Tooling:** Validators, converters, GUI editors

### For AI Agents

This repository uses shared agent context:
- Read **[`AGENTS.md`](AGENTS.md)** for shared project knowledge
- Read **[`CLAUDE.md`](CLAUDE.md)** or **[`GEMINI.md`](GEMINI.md)** for agent-specific instructions
- Update `AGENTS.md` when you learn patterns or decisions that benefit all agents

---

## License

- **Specification** (`docs/VOX-FORMAT.md`): [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) — Public Domain
- **Reference implementations**: To be determined (likely MIT or Apache 2.0)
- **Example files**: CC0 unless otherwise noted

---

## Authors

- **[intrusive-memory](https://github.com/intrusive-memory)** — Original specification and ecosystem integration

---

## Questions?

Open an issue on GitHub or reach out to the intrusive-memory team.

**Repository:** https://github.com/intrusive-memory/vox-format
**Ecosystem:** https://github.com/intrusive-memory
