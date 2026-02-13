# VoxFormat

A Swift library for reading, writing, and validating `.vox` voice identity files. VOX is an open, vendor-neutral file format that packages voice metadata, prosodic preferences, reference audio, and engine-specific extensions into a single ZIP-based archive. VoxFormat provides a type-safe API for working with these archives, supporting the full VOX specification including character context, provenance tracking, and multi-engine extensions. It is designed for integration with voice casting and text-to-speech synthesis workflows.

## Installation

Add VoxFormat to your Swift package dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/vox-format.git", from: "0.1.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "VoxFormat", package: "vox-format")
    ]
)
```

## Quick Start

**Read a .vox file:**

```swift
import VoxFormat

let reader = VoxReader()
let voxFile = try reader.read(from: URL(fileURLWithPath: "voice.vox"))
print(voxFile.manifest.voice.name)
print(voxFile.manifest.voice.description)
```

**Write a .vox file:**

```swift
import VoxFormat

let manifest = VoxManifest(
    voxVersion: "0.1.0",
    id: UUID().uuidString.lowercased(),
    created: Date(),
    voice: VoxManifest.Voice(
        name: "Narrator",
        description: "A warm, clear narrator voice."
    )
)
let writer = VoxWriter()
try writer.write(VoxFile(manifest: manifest), to: URL(fileURLWithPath: "output.vox"))
```

**Validate a manifest:**

```swift
import VoxFormat

let validator = VoxValidator()
try validator.validate(voxFile.manifest)
try validator.validate(voxFile.manifest, strict: true)
```

## API Reference

- **`VoxManifest`** -- Codable struct representing the voice identity manifest with nested types for `Voice`, `Prosody`, `ReferenceAudio`, `Character`, and `Provenance`.
- **`VoxFile`** -- Immutable container holding a parsed manifest, reference audio URLs, and an optional extensions directory.
- **`VoxReader`** -- Extracts and parses `.vox` ZIP archives into `VoxFile` instances.
- **`VoxWriter`** -- Creates `.vox` ZIP archives from `VoxFile` instances with manifest JSON and bundled assets.
- **`VoxValidator`** -- Validates manifests against the VOX specification with permissive (default) and strict modes.
- **`VoxError`** -- Enum covering all error cases: invalid ZIP, missing manifest, invalid JSON, validation failures, and I/O errors.

For full API documentation, generate DocC docs with:

```bash
swift package generate-documentation
```

## Examples

### Reading a .vox File

```swift
import VoxFormat

let reader = VoxReader()
let voxFile = try reader.read(from: URL(fileURLWithPath: "narrator.vox"))

let manifest = voxFile.manifest
print("Voice: \(manifest.voice.name)")
print("Description: \(manifest.voice.description)")

if let prosody = manifest.prosody {
    print("Pitch: \(prosody.pitchBase ?? "unspecified")")
    print("Rate: \(prosody.rate ?? "unspecified")")
}

if let provenance = manifest.provenance {
    print("Method: \(provenance.method ?? "unknown")")
    print("License: \(provenance.license ?? "unspecified")")
}

print("Reference audio files: \(voxFile.referenceAudioURLs.count)")
```

### Writing a .vox File

```swift
import VoxFormat

let manifest = VoxManifest(
    voxVersion: "0.1.0",
    id: UUID().uuidString.lowercased(),
    created: Date(),
    voice: VoxManifest.Voice(
        name: "Documentary Narrator",
        description: "A deep, authoritative voice for documentary narration.",
        language: "en-US",
        gender: "male",
        ageRange: [40, 55],
        tags: ["narrator", "documentary", "authoritative"]
    ),
    prosody: VoxManifest.Prosody(
        pitchBase: "low",
        pitchRange: "moderate",
        rate: "moderate",
        energy: "medium",
        emotionDefault: "calm authority"
    ),
    provenance: VoxManifest.Provenance(
        method: "designed",
        license: "CC0-1.0"
    )
)

let voxFile = VoxFile(manifest: manifest)
let writer = VoxWriter()
try writer.write(voxFile, to: URL(fileURLWithPath: "documentary-narrator.vox"))
```

### Validating a Manifest

```swift
import VoxFormat

let reader = VoxReader()
let voxFile = try reader.read(from: URL(fileURLWithPath: "voice.vox"))

let validator = VoxValidator()
do {
    try validator.validate(voxFile.manifest)
    print("Manifest is valid.")
} catch {
    print("Validation failed: \(error.localizedDescription)")
}
```

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines on contributing to the VOX format project, including coding standards, testing requirements, and the pull request process.
