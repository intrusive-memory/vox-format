# VoxFormat Python Library

A Python library for reading, writing, and validating VOX voice identity files. VOX is an open, vendor-neutral file format for voice identities used in text-to-speech synthesis.

## Overview

The `voxformat` library provides Python tools for working with `.vox` files, which are ZIP archives containing voice metadata, prosody preferences, reference audio, and character context. The library handles all aspects of VOX file I/O: reading existing files, creating new ones, and validating manifest structure against the VOX specification. It's designed for integration with TTS engines, voice casting tools, and audio production workflows.

## Installation

To install from PyPI:

```bash
pip install voxformat
```

For local development, install in editable mode:

```bash
git clone https://github.com/intrusive-memory/vox-format
cd vox-format/implementations/python
pip install -e .
```

## Quick Start

### Reading a VOX file

```python
from voxformat import VoxReader

reader = VoxReader()
vox_file = reader.read("narrator.vox")
print(vox_file.manifest.voice.name)
```

### Writing a VOX file

```python
from voxformat import VoxWriter, VoxFile, VoxManifest, Voice

manifest = VoxManifest(
    vox_version="0.1.0",
    id="550e8400-e29b-41d4-a716-446655440000",
    created="2025-01-15T10:30:00Z",
    voice=Voice(name="My Voice", description="A friendly narrator voice")
)
vox_file = VoxFile(manifest=manifest)
writer = VoxWriter()
writer.write(vox_file, "output.vox")
```

### Validating a manifest

```python
from voxformat import VoxValidator

validator = VoxValidator()
validator.validate(vox_file.manifest)  # Raises exception if invalid
```

## API Reference

The library provides five main modules:

- **manifest**: Data structures for VOX manifests (`VoxManifest`, `Voice`, `Prosody`, `ReferenceAudio`, `Character`, `Provenance`)
- **reader**: `VoxReader` class for reading `.vox` files from disk
- **writer**: `VoxWriter` class for creating `.vox` archives
- **validator**: `VoxValidator` class for validating manifest structure and field constraints
- **voxfile**: `VoxFile` class wrapping manifest and asset references

## Examples

### Reading a .vox file

```python
from pathlib import Path
from voxformat import VoxReader

# Read a VOX file
reader = VoxReader()
vox_path = Path("examples/minimal/narrator.vox")
vox_file = reader.read(vox_path)

# Access manifest data
manifest = vox_file.manifest
print(f"Voice: {manifest.voice.name}")
print(f"Description: {manifest.voice.description}")
print(f"Language: {manifest.voice.language}")

# Check for reference audio
if vox_file.reference_audio:
    for audio_path in vox_file.reference_audio:
        print(f"Reference audio: {audio_path}")
```

### Writing a .vox file

```python
from pathlib import Path
from voxformat import (
    VoxWriter, VoxFile, VoxManifest, Voice, Prosody
)
import uuid
from datetime import datetime, timezone

# Create a manifest programmatically
manifest = VoxManifest(
    vox_version="0.1.0",
    id=str(uuid.uuid4()),
    created=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    voice=Voice(
        name="Documentary Narrator",
        description="A warm, authoritative voice for documentary narration",
        language="en",
        gender="neutral",
        age_range=[35, 50],
        tags=["narrator", "documentary", "authoritative"]
    ),
    prosody=Prosody(
        pitch_base="low",
        rate="moderate",
        energy="calm"
    )
)

# Create VOX file and write to disk
vox_file = VoxFile(manifest=manifest)
writer = VoxWriter()
output_path = Path("my-narrator.vox")
writer.write(vox_file, output_path)
print(f"Created: {output_path}")
```

### Validating a manifest

```python
from voxformat import VoxValidator, VoxReader
from voxformat.errors import MultipleValidationErrors

reader = VoxReader()
validator = VoxValidator()

vox_file = reader.read("narrator.vox")

try:
    validator.validate(vox_file.manifest)
    print("✓ Manifest is valid")
except MultipleValidationErrors as e:
    print(f"✗ Validation failed with {len(e.errors)} error(s):")
    for error in e.errors:
        print(f"  - {error.field}: {error.message}")
```

## Contributing

Contributions are welcome! Please see the root [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines on submitting issues, proposing changes to the VOX specification, and adding new features to the reference implementations.

## License

This Python implementation is licensed under the MIT License. The VOX format specification itself is released under CC0 1.0 Universal (Public Domain).
