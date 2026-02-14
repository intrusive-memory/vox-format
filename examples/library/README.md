# VOX Voice Library

This directory contains curated `.vox` voice files organized by category for easy discovery and reuse.

## Categories

### Narrators (`narrators/`)

Professional narrator voices optimized for long-form content:
- **Audiobook narrators:** Warm, engaging, suitable for 8+ hour narration
- **Documentary narrators:** Authoritative, clear, educational tone
- **Storytelling narrators:** Expressive, dynamic, theatrical

### Characters (`characters/`)

Character voices for fiction, drama, and narrative production:
- Age-appropriate voices (young, middle-aged, elderly)
- Diverse emotional ranges and personalities
- Character context fields included (role, relationships)

### Accents (`accents/`)

Regional and international accent variations:
- Geographic distinctions (e.g., British RP, Southern US, Australian)
- Same base language, different pronunciation patterns
- Cultural authenticity when designed from description

## Naming Conventions

Voice files use descriptive kebab-case names:
- `narrators/audiobook.vox` - Self-explanatory purpose
- `characters/young-protagonist.vox` - Age + role
- `accents/british-rp.vox` - Region + style

Index entries use the same naming for consistency.

## Provenance Requirements

**CRITICAL:** All library voices MUST meet these requirements:

### Method: "designed"

All voices in this library are created from text descriptions only. No real person voices are included.

**Why?** This avoids consent and licensing complications. Description-designed voices are:
- Ethically unambiguous (no cloned identity)
- Legally safe (no person's likeness rights)
- Universally compatible (any TTS engine can interpret the description)

### License: CC0-1.0

All library voices are dedicated to the public domain under Creative Commons CC0 1.0 Universal.

**Why?** Maximum freedom for users:
- Use commercially without attribution
- Modify and redistribute freely
- No legal barriers to adoption

### Checklist for Adding Voices

Before adding a voice to the library, verify:

- [ ] `provenance.method` is `"designed"` (never `"cloned"`)
- [ ] `provenance.license` is `"CC0-1.0"`
- [ ] `voice.description` is detailed (100+ words)
- [ ] Voice validates successfully (`vox-cli validate --strict`)
- [ ] Unique use case (not redundant with existing library voices)
- [ ] Entry added to `library/index.json`
- [ ] Tags are descriptive and searchable

## Why No Real Person Voices?

Real person voices require:
1. **Explicit consent** from the voice owner
2. **License agreements** for commercial use
3. **Provenance verification** (who cloned when?)
4. **Liability risk** (deepfake misuse, identity theft)

By restricting the library to description-designed voices, we eliminate these concerns entirely.

## Contributing

To contribute a voice:
1. Read the provenance requirements above
2. Create the `.vox` file using `vox-cli create`
3. Validate with `vox-cli validate --strict`
4. Add entry to `library/index.json`
5. Submit PR with rationale for inclusion

See root `CONTRIBUTING.md` for full guidelines.

---

**Last Updated:** 2026-02-13
