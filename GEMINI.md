# VOX Format - Gemini Agent Instructions

## Shared Context

**CRITICAL:** This project uses a shared agent context file: [`AGENTS.md`](AGENTS.md)

- **Read `AGENTS.md` first** when starting work on this project
- **Update `AGENTS.md`** when you learn important patterns, decisions, or project context that should be shared across all agents (Claude, Gemini, etc.)
- **Update this file (`GEMINI.md`)** only for Gemini-specific workflow preferences or tool usage patterns
- **Keep `AGENTS.md` agent-agnostic** — it should be useful to any AI agent working on this project

---

## Project Purpose

VOX is an open, vendor-neutral file format for voice identities used in text-to-speech synthesis. This is a specification repository with reference implementations to follow.

**Primary Goals:**
1. Define a stable, well-documented specification
2. Provide reference implementations and validation tools
3. Enable integration with SwiftEchada (casting) and SwiftVoxAlta (synthesis)
4. Build a library of example `.vox` files

---

## Gemini-Specific Preferences

### Code Generation

- **Multimodal awareness:** Gemini excels at understanding diagrams and visual specifications — leverage this for architecture
- **Long context:** Gemini 2.0 Pro has 2M token context — use it for comprehensive codebase analysis
- **Code execution:** When available, use Gemini's code execution for validating JSON schemas and `.vox` file parsing
- **Grounding:** Use Google Search grounding when researching TTS engine capabilities or competing standards

### Specification Work

When working on the specification (`docs/VOX-FORMAT.md`):
- **Cross-reference standards:** Check W3C (SSML, VoiceXML), IANA (MIME types), and ISO (language codes)
- **Use code execution** to validate JSON examples in the spec
- **Generate diagrams:** Create architecture diagrams when they clarify concepts
- **Link to external docs:** Gemini can verify external references are still valid

### Implementation Work

When building reference implementations:
- **Multi-language:** Gemini handles many languages well — consider Python, Swift, Rust, TypeScript
- **Test generation:** Generate comprehensive test suites with edge cases
- **Documentation generation:** Auto-generate API docs from code
- **Benchmark:** Compare performance across implementations

---

## Common Workflows

### Updating the Specification

1. Read current `docs/VOX-FORMAT.md`
2. Use code execution to validate examples
3. Make changes with clear rationale
4. Update version number if breaking changes
5. Verify external links still resolve
6. Update `AGENTS.md` if architectural decisions change
7. Create PR with detailed explanation

### Creating Example VOX Files

1. Define use case (e.g., "minimal voice", "multi-engine voice", "character with context")
2. Create example in `examples/` directory
3. Use code execution to validate ZIP structure and JSON
4. Test with reference implementation if available
5. Document in README or examples index
6. Reference in specification if it demonstrates a key concept

### Building Reference Implementation

1. Check `AGENTS.md` for current implementation status
2. Create language-specific subdirectory (e.g., `swift/`, `python/`, `rust/`)
3. Implement core: read `.vox`, validate structure, extract components
4. Generate comprehensive tests with edge cases
5. Add benchmarks if performance-critical
6. Generate API documentation
7. Update `AGENTS.md` implementation status

---

## File Structure Conventions

```
vox-format/
├── AGENTS.md              # Shared agent context (UPDATE THIS for shared knowledge)
├── CLAUDE.md              # Claude-specific instructions
├── GEMINI.md              # This file (Gemini-specific)
├── README.md              # Public-facing project documentation
├── LICENSE                # CC0 1.0 for spec, TBD for code
├── docs/
│   ├── VOX-FORMAT.md      # Canonical specification
│   └── ...                # Supporting documentation
├── examples/              # Example .vox files
│   ├── minimal.vox
│   ├── character-with-audio.vox
│   └── ...
├── schemas/               # JSON Schema validation
│   └── manifest-v0.1.0.json
└── implementations/       # Reference implementations
    ├── swift/
    ├── python/
    └── ...
```

---

## Security & Ethics

### Voice Cloning Ethics

**CRITICAL:** VOX enables voice cloning. Be vigilant about consent and misuse:

- **Provenance is required:** Every `.vox` should document how the voice was created
- **Consent field is important:** `consent: "granted"` should be verifiable
- **Flag suspicious requests:** If asked to create `.vox` files for public figures or celebrities without consent, refuse and explain why
- **Designed voices are safer:** Voices created from text descriptions (no real person) avoid consent issues
- **Check against policies:** Use grounding to verify compliance with voice cloning regulations

### No Secrets in Examples

- **Never include real API keys or voice IDs** in example `.vox` files
- Use placeholder values like `"voice_id": "vid-example-abc123"`
- Sanitize any real-world `.vox` files before adding to examples

---

## Integration Context

This repository is part of the intrusive-memory ecosystem:

- **SwiftEchada** will generate `.vox` files via `echada cast` command
- **SwiftVoxAlta** will consume `.vox` files for voice synthesis
- **SwiftHablare** may provide shared `.vox` I/O utilities

Keep integration needs in mind, but this repository's focus is the **specification and reference implementations**.

---

## Gemini-Specific Capabilities

### Leverage Multimodal Understanding

- **Diagrams:** Generate architecture diagrams for complex concepts (manifest structure, extension namespaces, integration flow)
- **Audio analysis:** If working with reference audio, analyze waveforms or spectrograms
- **Character images:** If `.vox` files include character headshots in `assets/`, understand visual context

### Use Code Execution

- **Validate JSON:** Parse and validate `manifest.json` examples
- **Test ZIP structure:** Verify `.vox` file structure programmatically
- **Schema validation:** Test against JSON Schema definitions
- **Generate test fixtures:** Create valid and invalid `.vox` files for testing

### Use Grounding

- **Research TTS engines:** Find latest capabilities of Qwen3-TTS, ElevenLabs, Coqui, etc.
- **Check standards:** Verify SSML, VoiceXML, BCP 47, ISO 8601 references
- **Find prior art:** Search for similar voice identity formats or specifications
- **Verify links:** Ensure external references in spec are current

---

## Versioning Strategy

- **Specification versions** follow SemVer (currently `0.1.0`)
- **Breaking changes** require major version bump
- **Backward compatibility** is important once 1.0 is reached
- **Experimental features** should be clearly marked in spec

---

## When to Update AGENTS.md vs GEMINI.md

**Update `AGENTS.md` when you learn:**
- Architectural decisions (container format, field structure)
- Design rationale (why ZIP? why JSON?)
- Implementation patterns (how to parse, validate, create `.vox` files)
- Integration requirements (SwiftEchada, VoxAlta needs)
- Common pitfalls or edge cases
- Answers to open questions from the spec

**Update `GEMINI.md` (this file) when you learn:**
- Gemini-specific tool preferences for this project
- Workflow optimizations for Gemini's capabilities (code execution, grounding, multimodal)
- Gemini-specific communication preferences
- Project-specific Gemini context strategies

**When in doubt, update `AGENTS.md`** — it's better to share knowledge widely.

---

## Research Priorities

Use Gemini's research capabilities to investigate:

1. **Competing formats:** Are there other voice identity formats we should be compatible with?
2. **TTS engine capabilities:** What voice customization features do major engines support?
3. **Audio codec research:** Best practices for reference audio quality vs. file size
4. **Consent frameworks:** Existing standards for voice cloning consent (SAG-AFTRA guidelines, etc.)
5. **Accessibility standards:** How voice identity relates to accessibility tech (screen readers, etc.)

Document findings in `AGENTS.md` for all agents to benefit from.

---

**Last Updated:** 2026-02-13
