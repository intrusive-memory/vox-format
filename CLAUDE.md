# VOX Format - Claude Agent Instructions

## Shared Context

**CRITICAL:** Read [`AGENTS.md`](AGENTS.md) first. It is the primary source of project knowledge — architecture, API patterns, implementation status, and code examples. This file contains only Claude-specific workflow preferences.

- **Update `AGENTS.md`** for project knowledge shared across all agents
- **Update this file** only for Claude-specific tool or workflow preferences

---

## Claude-Specific Preferences

### Tool Usage

- **File Operations:** Use dedicated tools (Read, Write, Edit, Glob, Grep) instead of Bash commands
- **Git Operations:** Use Bash for git commands (commit, push, branch management)
- **Building/Testing:** Use XcodeBuildMCP tools (`swift_package_build`, `swift_package_test`) — never `swift build` or `swift test`
- **Testing:** Run tests after significant changes to the Swift implementation

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

1. Check `AGENTS.md` for current implementation status and API patterns
2. Implement against the container-first `VoxFile` API
3. Add tests with example files
4. Document usage and API
5. Update `AGENTS.md` implementation status

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

## When to Update AGENTS.md vs CLAUDE.md

**Update `AGENTS.md` when you learn:**
- Architectural decisions, API changes, design rationale
- Implementation patterns, code examples, key types
- Integration requirements, common pitfalls, edge cases

**Update `CLAUDE.md` (this file) when you learn:**
- Claude-specific tool preferences for this project
- Workflow optimizations for Claude's capabilities

**When in doubt, update `AGENTS.md`** — it's better to share knowledge widely.

---

**Last Updated:** 2026-02-21
