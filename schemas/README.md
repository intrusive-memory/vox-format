# VOX Manifest JSON Schema

## Overview

This directory contains the JSON Schema definition for the VOX manifest format. The schema provides machine-readable validation rules for `manifest.json` files found inside `.vox` archives. It enforces structural constraints such as required fields, data types, string patterns (UUID v4, ISO 8601 timestamps, semver), and enumerated values. Use the schema during development to catch malformed manifests early, in CI pipelines to gate releases, or in editor integrations for live feedback while authoring voice identity files.

The current schema version is **v0.1.0**, targeting JSON Schema Draft 2020-12.

## Installation

Install one of the following validation tools:

**Python (jsonschema)**
```bash
pip install jsonschema
```

**Python (check-jsonschema CLI)**
```bash
pip install check-jsonschema
```

**Node.js (ajv-cli)**
```bash
npm install -g ajv-cli
```

## Usage

### Validating a Manifest

Validate a standalone `manifest.json` file against the schema:

```bash
# Using check-jsonschema
check-jsonschema --schemafile schemas/manifest-v0.1.0.json examples/minimal/manifest.json

# Using ajv-cli
ajv validate -s schemas/manifest-v0.1.0.json -d examples/minimal/manifest.json --spec=draft2020

# Using Python jsonschema
python3 -c "
import json, jsonschema
schema = json.load(open('schemas/manifest-v0.1.0.json'))
data = json.load(open('examples/minimal/manifest.json'))
jsonschema.validate(data, schema)
print('Valid')
"
```

### Validating a .vox File

Extract the manifest from a `.vox` archive and validate it:

```bash
tmpdir=$(mktemp -d)
unzip -q my-voice.vox -d "$tmpdir"
check-jsonschema --schemafile schemas/manifest-v0.1.0.json "$tmpdir/manifest.json"
rm -rf "$tmpdir"
```

### Running All Validations

The included validation script tests all example manifests and `.vox` archives, plus negative test cases:

```bash
bash schemas/validate-examples.sh
```

This script validates 6 positive examples (3 standalone manifests, 3 `.vox` archives) and 5 negative test cases in `schemas/test/`.

## Tools

| Tool | Language | Install Command | Notes |
|------|----------|-----------------|-------|
| [jsonschema](https://python-jsonschema.readthedocs.io/) | Python | `pip install jsonschema` | Library for programmatic use |
| [check-jsonschema](https://check-jsonschema.readthedocs.io/) | Python | `pip install check-jsonschema` | CLI wrapper around jsonschema |
| [ajv-cli](https://ajv.js.org/) | Node.js | `npm install -g ajv-cli` | Fast, widely used CLI validator |
| [jv](https://github.com/santhosh-tekuri/jsonschema) | Go | `go install github.com/santhosh-tekuri/jsonschema/cmd/jv@latest` | Lightweight Go validator |
| [yajsv](https://github.com/neilpa/yajsv) | Go | `go install github.com/neilpa/yajsv@latest` | Batch validation support |

## Troubleshooting

**Error: `'vox_version' is a required property`**
The manifest is missing the `vox_version` field. Every VOX manifest must include `"vox_version": "0.1.0"` at the top level. Ensure the field name is spelled exactly as `vox_version` (with underscore, not camelCase).

**Error: `'<value>' does not match '<pattern>'`**
A string field does not match its required format. Common causes: the `id` field is not a valid UUID v4 (must be lowercase hex with the version-4 nibble), or the `created` field is not in ISO 8601 format (must be `YYYY-MM-DDTHH:MM:SSZ` or with a timezone offset like `+05:30`). Double-check the exact format requirements in the schema.

## References

- [JSON Schema Specification (Draft 2020-12)](https://json-schema.org/draft/2020-12/json-schema-core)
- [Understanding JSON Schema](https://json-schema.org/understanding-json-schema/)
- [VOX Format Specification](../docs/VOX-FORMAT.md)
- [VOX Example Files](../examples/)
