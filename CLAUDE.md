# VOX Format - Claude Agent Instructions

## Shared Context

**CRITICAL:** This project uses a shared agent context file: [`AGENTS.md`](AGENTS.md)

- **Read `AGENTS.md` first** when starting work on this project
- **Update `AGENTS.md`** when you learn important patterns, decisions, or project context that should be shared across all agents (Claude, Gemini, etc.)
- **Update this file (`CLAUDE.md`)** only for Claude-specific workflow preferences or tool usage patterns
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

## Claude-Specific Preferences

### Tool Usage

- **File Operations:** Use dedicated tools (Read, Write, Edit, Glob, Grep) instead of Bash commands
- **Git Operations:** Use Bash for git commands (commit, push, branch management)
- **Testing:** When reference implementations exist, run tests after significant changes

### Communication Style

- **Candor:** Flag risks, trade-offs, and potential issues directly
- **Conciseness:** Keep responses short and focused
- **Code References:** Use `file_path:line_number` format when referencing specific locations

### Specification Work

When working on the specification (`docs/VOX-FORMAT.md`):
- **Clarity over brevity:** Specifications should be unambiguous
- **Examples are essential:** Include JSON examples for every concept
- **Version carefully:** Specification changes may require version bumps
- **Document rationale:** Explain *why* design decisions were made

### Implementation Work

When building reference implementations:
- **Start simple:** Minimal viable implementation first, then enhance
- **Validate early:** Test against example `.vox` files from the start
- **Document edge cases:** Real-world `.vox` files will be messy
- **Performance matters:** `.vox` files may be loaded frequently in production

---

## Common Workflows

### Updating the Specification

1. Read current `docs/VOX-FORMAT.md`
2. Make changes with clear rationale
3. Update version number if breaking changes
4. Add/update examples
5. Update `AGENTS.md` if architectural decisions change
6. Create PR with detailed explanation

### Creating Example VOX Files

1. Define use case (e.g., "minimal voice", "multi-engine voice", "character with context")
2. Create example in `examples/` directory
3. Validate JSON structure
4. Document in README or examples index
5. Reference in specification if it demonstrates a key concept

### Building Reference Implementation

1. Check `AGENTS.md` for current implementation status
2. Create language-specific subdirectory (e.g., `swift/`, `python/`, `rust/`)
3. Implement core: read `.vox`, validate structure, extract components
4. Add tests with example files
5. Document usage and API
6. Update `AGENTS.md` implementation status

---

## File Structure Conventions

```
vox-format/
├── AGENTS.md              # Shared agent context (UPDATE THIS for shared knowledge)
├── CLAUDE.md              # This file (Claude-specific)
├── GEMINI.md              # Gemini-specific instructions
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

## Versioning Strategy

- **Specification versions** follow SemVer (currently `0.1.0`)
- **Breaking changes** require major version bump
- **Backward compatibility** is important once 1.0 is reached
- **Experimental features** should be clearly marked in spec

---

## When to Update AGENTS.md vs CLAUDE.md

**Update `AGENTS.md` when you learn:**
- Architectural decisions (container format, field structure)
- Design rationale (why ZIP? why JSON?)
- Implementation patterns (how to parse, validate, create `.vox` files)
- Integration requirements (SwiftEchada, VoxAlta needs)
- Common pitfalls or edge cases
- Answers to open questions from the spec

**Update `CLAUDE.md` (this file) when you learn:**
- Claude-specific tool preferences for this project
- Workflow optimizations for Claude's capabilities
- Claude-specific communication preferences
- Project-specific Claude memory/context strategies

**When in doubt, update `AGENTS.md`** — it's better to share knowledge widely.

---

**Last Updated:** 2026-02-13
