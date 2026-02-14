# Contributing to VOX Format

## Overview

Thank you for your interest in contributing to the VOX Format project! VOX is an open, vendor-neutral file format for persisting voice identities across text-to-speech systems. This project welcomes contributions in the form of specification improvements, example voices, reference implementations, tooling, and documentation.

We value thoughtful design, clear documentation, and ethical voice usage. Whether you're fixing a typo, proposing a new field, or implementing VOX support in a new programming language, your contributions help make voice portability a reality.

---

## Spec Changes

The VOX specification is defined in `docs/VOX-FORMAT.md`. Changes to the spec require careful consideration due to the impact on implementations and existing `.vox` files.

### Process for Proposing Spec Changes

1. **Open an issue first.** Before submitting a pull request with spec changes, open a GitHub issue describing:
   - The problem you're solving or use case you're enabling
   - Your proposed solution (new field, changed behavior, etc.)
   - Rationale for the change
   - Impact on backward compatibility

2. **Discuss rationale.** Maintainers and community members will discuss the proposal. Questions to address:
   - Is this solving a real problem for TTS workflows?
   - Can this be achieved with existing fields?
   - Does it align with VOX's vendor-neutral philosophy?
   - What's the trade-off between complexity and utility?

3. **Submit a PR with version bump if breaking.** Once consensus is reached:
   - Update `docs/VOX-FORMAT.md` with the change
   - If the change is breaking (removes fields, changes required fields, alters semantics), increment the major version (e.g., `0.1.0` → `0.2.0`)
   - If the change is additive (new optional fields), increment the minor version (e.g., `0.1.0` → `0.1.1`)
   - Update `schemas/manifest-v{version}.json` to match
   - Update example `.vox` files if they demonstrate the new feature

4. **Document design decisions.** Include rationale in the spec or in comments. Future contributors (and your future self) will thank you.

---

## Examples

The `examples/` directory contains reference `.vox` files demonstrating various use cases. New examples are welcome!

### Checklist for Adding .vox Files

- [ ] File must validate against `schemas/manifest-v{version}.json` using ajv-cli or check-jsonschema
- [ ] File must have a unique use case (don't duplicate existing examples)
- [ ] File must be documented in `examples/README.md` with description and use case
- [ ] File must use description-only voice design OR public domain/CC0 audio (no copyrighted or non-consented audio)
- [ ] Manifest must include `provenance` field explaining how the voice was created
- [ ] If using reference audio, files must be WAV format, 24kHz, 16-bit PCM, mono
- [ ] File must be named descriptively (e.g., `narrator-with-context.vox`, not `test.vox`)

Run validation before submitting:

```bash
# Extract manifest
unzip -p examples/your-file.vox manifest.json > /tmp/manifest.json

# Validate
ajv validate -s schemas/manifest-v0.1.0.json -d /tmp/manifest.json
```

---

## Implementations

VOX reference implementations live in `implementations/{language}/`. Currently supported:
- **Swift** (macOS/iOS) — `implementations/swift/`
- **Python** (cross-platform) — `implementations/python/` (in progress)

### Guidelines for New Language Implementations

If you want to add VOX support for a new programming language:

1. **Must have read/write/validate.** Core functionality:
   - Read a `.vox` file (unzip, parse manifest, enumerate assets)
   - Write a `.vox` file (encode manifest, create ZIP archive)
   - Validate a manifest against the spec (required fields, formats, constraints)

2. **Must pass all examples.** Your implementation should successfully read and validate all files in `examples/`.

3. **Must have tests.** Minimum test coverage:
   - Unit tests for manifest decoding/encoding
   - Unit tests for validation logic
   - Integration tests with real `.vox` files
   - Target: 80%+ code coverage

4. **Must have documentation.** Include a README in your implementation directory with:
   - Installation instructions
   - Quick start example (read, write, validate)
   - API reference or link to generated docs

5. **Follow language idioms.** Use the conventions of your language (e.g., snake_case in Python, camelCase in JavaScript, SwiftLint in Swift).

---

## Code Style

### Swift

- Use [SwiftLint](https://github.com/realm/SwiftLint) rules (see `.swiftlint.yml` if present)
- Follow Swift API Design Guidelines
- Use DocC-style documentation comments for all public APIs
- Prefer `struct` over `class` for immutable data
- Use `Codable` for JSON serialization

### Python

- Use [Black](https://black.readthedocs.io/) formatting (line length 100)
- Type hints required for all function signatures
- Docstrings required for all public classes/functions (Google style)
- Use `dataclasses` for data structures
- Use `pathlib.Path` for file paths (not strings)

Run formatters before committing:

```bash
# Swift
swiftlint autocorrect

# Python
black implementations/python/
```

---

## Testing

All contributions that add or modify code must include tests.

### Minimum Coverage Expectations

- **80%+ code coverage** for new implementations
- **100% coverage** for validation logic (critical path)
- **Integration tests** with real `.vox` files from `examples/`

### Running Tests

```bash
# Swift
cd implementations/swift
swift test

# Python
cd implementations/python
pytest --cov=voxformat --cov-report=term-missing
```

### Writing Good Tests

- Test both success and failure cases
- Use descriptive test names (e.g., `testValidateRejectsEmptyDescription`)
- Test edge cases (empty strings, missing fields, invalid UUIDs)
- Avoid brittle tests that depend on specific file paths or timestamps

---

## PR Process

1. **Fork the repository.** Create your own fork of `intrusive-memory/vox-format`.

2. **Create a branch.** Use a descriptive branch name:
   - `feature/add-python-implementation`
   - `fix/validation-uuid-check`
   - `docs/update-examples-readme`

3. **Make changes.** Follow the guidelines above for your contribution type.

4. **Run tests.** Ensure all tests pass before submitting:
   ```bash
   # Swift
   cd implementations/swift && swift test

   # Validate examples
   bash schemas/validate-examples.sh
   ```

5. **Submit PR.** Open a pull request with:
   - Clear title and description
   - Reference to related issue (if applicable)
   - Explanation of what changed and why
   - Confirmation that tests pass

Maintainers will review your PR and may request changes. Once approved, your contribution will be merged!

---

## Questions?

If you're unsure about anything, open a GitHub issue or discussion. We're here to help!

Thank you for contributing to VOX! 🎙️
