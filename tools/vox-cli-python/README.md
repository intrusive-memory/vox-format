# vox-cli (Python)

A command-line tool for working with `.vox` voice identity files.

## Overview

`vox-cli` provides a set of commands for creating, inspecting, validating, and extracting VOX voice identity archives. VOX is an open, vendor-neutral file format for voice identities used in text-to-speech synthesis. This Python-based CLI makes it easy to work with `.vox` files during development, testing, and production workflows. The tool supports all features of the VOX format specification including voice metadata, prosody preferences, character context, reference audio, provenance tracking, and engine-specific extensions.

## Installation

Install from PyPI:

```bash
pip install vox-cli
```

For local development, install in editable mode:

```bash
cd tools/vox-cli-python
pip install -e .
```

Verify installation:

```bash
vox --version
vox --help
```

## Commands

### inspect

Display detailed information about a .vox file, including all metadata fields, reference audio files, character context, and extensions.

**Usage:**

```bash
vox inspect <file.vox>
```

**Example:**

```bash
vox inspect examples/minimal/narrator.vox
```

**Output:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VOX File: narrator.vox
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Core Metadata
  VOX Version: 0.1.0
  ID: ad7aa7d7-570d-4f9e-99da-1bd14b99cc78
  Created: 2026-02-13T12:00:00Z

🎤 Voice Identity
  Name: Narrator
  Description: A warm, clear narrator voice with neutral accent.
  Language: en
...
```

---

### validate

Validate a .vox file against the VOX format specification. By default, uses permissive validation (forward-compatible). Use `--strict` for development/testing.

**Usage:**

```bash
vox validate [--strict] <file.vox>
```

**Example:**

```bash
vox validate narrator.vox
vox validate --strict examples/character/protagonist.vox
```

**Output:**

```
✅ PASS: narrator.vox

Validation mode: permissive (default)
Voice: Narrator
Version: 0.1.0
```

Exits with code 0 if valid, 1 if validation fails.

---

### create

Create a new .vox file with specified metadata. Required fields (UUID, timestamp) are auto-generated. Supports optional voice attributes like language and gender.

**Usage:**

```bash
vox create --name <name> --description <description> --output <file.vox> [options]
```

**Options:**

- `--name` (required): Display name for the voice
- `--description` (required): Natural language description (minimum 10 characters)
- `--output` (required): Output file path
- `--language`: Primary language in BCP 47 format (e.g., `en-US`, `en-GB`, `fr-FR`)
- `--gender`: Gender presentation (`male`, `female`, `nonbinary`, `neutral`)

**Example:**

```bash
vox create \
  --name "Narrator" \
  --description "A warm, clear narrator voice for audiobooks" \
  --output narrator.vox

vox create \
  --name "Doc Narrator" \
  --description "Documentary narrator with authoritative British accent" \
  --language "en-GB" \
  --gender "male" \
  --output documentary.vox
```

**Output:**

```
✅ Created: narrator.vox

Voice: Narrator
ID: 53aa6c0d-e3bb-4c9f-a961-fc6b3fad2933
Created: 2026-02-13T23:13:20Z

Output: narrator.vox

Validating created file...
✅ Validation passed
```

---

### extract

Extract the contents of a .vox archive to a directory. Unzips all files (manifest.json, reference audio, embeddings) and displays the pretty-printed manifest.

**Usage:**

```bash
vox extract <file.vox> [--output-dir <directory>]
```

**Example:**

```bash
vox extract narrator.vox
vox extract examples/character/protagonist.vox --output-dir extracted/
```

**Output:**

```
📦 Extracting: protagonist.vox
Destination: extracted/

  ✓ manifest.json
  ✓ reference/sample-01.wav

Extracted 2 files

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Manifest Contents
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{
  "created": "2026-02-13T12:00:00Z",
  "id": "...",
  "voice": {
    "description": "...",
    "name": "..."
  },
  "vox_version": "0.1.0"
}
```

---

## Workflows

### Creating a Voice

1. **Design the voice**: Write a detailed description of voice characteristics (accent, tone, age, personality).

2. **Create the .vox file**:

   ```bash
   vox create \
     --name "PROTAGONIST" \
     --description "Young adult protagonist, energetic, optimistic" \
     --language "en-US" \
     --gender "neutral" \
     --output protagonist.vox
   ```

3. **Validate the result**:

   ```bash
   vox validate protagonist.vox
   ```

4. **Inspect the contents**:

   ```bash
   vox inspect protagonist.vox
   ```

---

### Validating Existing Files

Use this workflow when integrating .vox files from other sources or verifying files before deployment:

1. **Validate with default (permissive) mode**:

   ```bash
   vox validate voice.vox
   ```

2. **If validation passes, inspect details**:

   ```bash
   vox inspect voice.vox
   ```

3. **For development, use strict mode**:

   ```bash
   vox validate --strict voice.vox
   ```

---

### Inspecting Voice Details

When you need to understand what's inside a .vox file:

1. **Quick inspection**:

   ```bash
   vox inspect voice.vox
   ```

2. **Extract to examine raw files**:

   ```bash
   vox extract voice.vox --output-dir voice-contents/
   cd voice-contents/
   cat manifest.json
   ls -la reference/
   ```

3. **Validate structure**:

   ```bash
   vox validate voice.vox
   ```

---

## Troubleshooting

### Error: "Not a valid ZIP archive"

**Cause:** The file is corrupted or not a .vox file.

**Solution:** Verify the file is a valid ZIP archive:

```bash
python -m zipfile -l voice.vox
file voice.vox  # Should show "Zip archive data"
```

---

### Error: "manifest.json not found in archive"

**Cause:** The .vox file is missing the required manifest.json at the archive root.

**Solution:** Extract the archive and verify structure:

```bash
vox extract voice.vox --output-dir extracted/
ls -la extracted/  # Should show manifest.json
```

A valid .vox file must have `manifest.json` at the root level.

---

### Error: "Validation failed"

**Cause:** The manifest contains invalid or missing required fields.

**Solution:** Inspect the file to see what fields are present:

```bash
vox inspect voice.vox
```

Check the validation error message for specific issues (e.g., "voice.description is too short"). Required fields:

- `vox_version` (string, e.g., "0.1.0")
- `id` (UUID v4 format)
- `created` (ISO 8601 timestamp)
- `voice.name` (non-empty string)
- `voice.description` (minimum 10 characters)

---

## See Also

- [VOX Format Specification](../../docs/VOX-FORMAT.md)
- [VoxFormat Python Library](../../implementations/python/README.md)
- [Example .vox Files](../../examples/README.md)
- [GitHub Repository](https://github.com/intrusive-memory/vox-format)
