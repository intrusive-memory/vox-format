# TODO — Optional Per-Language Samples in `.vox`

**Status:** ✅ **OK to start.** All blocking decisions resolved by the user 2026-06-08 (see Decisions Locked below). Remaining items in §10 are non-blocking refinements with adopted defaults.
**Author:** research pass, 2026-06-08.
**Target schema version:** `0.4.0` (additive minor bump — see Decision D4).

### Decisions Locked (user, 2026-06-08)
- **D1 — Path scheme:** `embeddings/<engine>/<slug>/<lang>/...` (language segment appended under the existing `embeddings/` tree). **NO new `samples/` tree.** The sibling echada + SwiftVoxAlta TODOs match this.
- **D2 — Scope:** **Both** per-language **clone prompts** AND per-language sample audio. The clone prompt is the load-bearing one (it drives synthesis); §3c is now mandatory, not conditional.
- **3-repo coordinated effort:** vox-format (this) → SwiftVoxAlta (`VoxExporter` language paths + `VoxImporter` language read + `createLock(language:)`) → echada. Produciesta render-side selection is handled separately by the user.

---

## 1. Problem Statement

A `.vox` file today carries, per model variant, a single language-less **sample audio** (and a single **clone-prompt** embedding). Sample audio lives as an *embedding entry* whose `file` contains `sample-audio`, under `embeddings/<engine>/<slug>/sample-audio.wav`. We want a `.vox` to *optionally* carry **one or more language-specific samples for the same model**, alongside the existing default (language-less) sample.

### Exact fallback semantics (CRITICAL — implement verbatim)

Given a lookup `(model, language)`:

1. If a sample exists for **exactly that (model, language)** → return it.
2. Else if a **language-less / default** sample exists for that model → return it.
3. Else → return `nil` (current behavior; never throw solely because a language is missing).

`language == nil` or `language == "default"` MUST behave **exactly as today** (resolve the default/language-less sample, then legacy fallback). This is the entire backward-compat contract for readers.

---

## 2. ✅ RESOLVED — Path scheme adopted (sibling echada + SwiftVoxAlta TODOs match)

**DECIDED (D1): the language segment is appended under the existing `embeddings/` tree. No `samples/` tree.** Rationale below stands. The original brief proposed `samples/<engine>/<slug>/<lang>/...`, but **the codebase does not use a `samples/` tree.** Sample audio is stored as an **embedding entry** under `embeddings/`:

- Path convention (writer): `embeddings/qwen3-tts/<slug>/sample-audio.wav`
  — `SwiftVoxAlta/Sources/SwiftVoxAlta/VoxExporter.swift:25` (`sampleAudioPath(for:)`)
- Lookup is by **filename substring `"sample-audio"`** + model match, NOT by a `samples/` prefix
  — `implementations/swift/Sources/VoxFormat/VoxFile+ModelQuery.swift:140` (`sampleAudioData(for:)`)
- The schema even *requires* embedding `file` to start with `embeddings/`
  — `schemas/manifest-v0.3.0.json:299` (`"pattern": "^embeddings/"`)
  — enforced in code at `implementations/swift/Sources/VoxFormat/VoxFile+Validation.swift:190`

**Recommended (and assumed below): keep samples in `embeddings/`, add the language as a path segment after the slug:**

```
embeddings/qwen3-tts/0.6b/sample-audio.wav         ← default (unchanged, language-less)
embeddings/qwen3-tts/0.6b/es/sample-audio.wav      ← Spanish sample
embeddings/qwen3-tts/0.6b/fr-FR/sample-audio.wav   ← French (France) sample
```

A brand-new top-level `samples/` tree was rejected — it would be a larger, breaking-ish change (the `^embeddings/` schema pattern and the `embeddings/` reader prefix all assume the current layout). **The `embeddings/<engine>/<slug>/<lang>/...` append scheme is final; all three repos use it.**

---

## 3. Proposed API Contract (final names)

### 3a. Read API — `VoxFile+ModelQuery.swift`

Add an overload (keep the old one for source compat):

```swift
/// Returns sample audio for (model, language) with default-language fallback.
/// - language: nil or "default" → current language-less behavior.
public func sampleAudioData(for query: String, language: String?) -> Data?
```

- Implement steps 1→2→3 from §1.
- Keep existing `sampleAudioData(for:)` as `sampleAudioData(for: query, language: nil)`.
- **Checklist:**
  - [ ] `VoxFile+ModelQuery.swift:140` — refactor `sampleAudioData(for:)` to delegate to the new overload.
  - [ ] Add the new overload that, when `language` is non-nil/non-`"default"`, first searches embedding entries whose `file` contains `sample-audio` AND whose resolved language matches, then falls back to the language-less match, then the legacy `embeddings/qwen3-tts/sample-audio.wav` path (`VoxFile+ModelQuery.swift:157`).
  - [ ] Language match must be **case-insensitive** and tolerate base-language fallback (a query of `"fr-FR"` should match a stored `"fr"` sample if no exact `fr-FR` exists — see Decision D6; decide and document precisely).
  - [ ] DECIDE (Decision D3): does `language` live in the **path segment**, the **entry metadata (`language` field on EmbeddingEntry)**, or **both**? The matcher must read from whichever is the source of truth. Recommendation below: metadata field is source of truth, path segment is convention only.
  - [ ] Add a discovery helper: `public func sampleAudioLanguages(for query: String) -> [String]` returning the languages available for a model (empty = default-only). Consumers (echada CLI `inspect`, Produciesta) need this to know what exists.

### 3b. Write API — `VoxFile.add(...)` + AutoManifest

The generic `add(_:at:metadata:)` already accepts arbitrary metadata. The language must flow into the manifest. Two sub-decisions:

- **Path:** writer chooses `embeddings/<engine>/<slug>/<lang>/sample-audio.wav` for language-specific, unchanged path for default.
- **Metadata:** pass `"language": "<bcp47>"` in the `add` metadata dict.

- **Checklist:**
  - [ ] `VoxFile+AutoManifest.swift:68` (`addEmbeddingManifestEntry`) — read `entry.metadata["language"]` and set it on the new `EmbeddingEntry.language` field (see §4).
  - [ ] `VoxFile+AutoManifest.swift:91` (`deriveEmbeddingKey`) — confirm the derived key stays unique across languages. With a `<lang>` path segment it already will: `embeddings/qwen3-tts/0.6b/es/sample-audio.wav` → `qwen3-tts-0.6b-es-sample-audio`. ✅ No key collision with the default. **Add a test asserting this.**
  - [ ] `SwiftVoxAlta/Sources/SwiftVoxAlta/VoxExporter.swift:25,66` — add `language:` parameter to `sampleAudioPath(for:)` and `addSampleAudio(to:data:modelRepo:language:)`. Default `nil` preserves current path. This is the **echada/VoxAlta-side change** the sibling TODO owns; vox-format only provides the data field + matcher.

### 3c. Embeddings (clone-prompts) — SAME treatment ✅ (Decision D2 — CONFIRMED YES)

`clonePromptData(for:)` (`VoxFile+ModelQuery.swift:113`) is structurally identical to `sampleAudioData(for:)` (substring `"clone-prompt"` instead of `"sample-audio"`). echada **will** store a **per-language clone prompt** (a Spanish voice lock vs an English one for the same model), so it needs the *same* `(model, language)` + fallback API.

- **DECIDED:** apply the identical treatment to `clonePromptData(for:language:)`. The clone prompt is what actually drives synthesis; a sample is just a preview. **This is the load-bearing one — mandatory, not optional.**
- **Checklist (REQUIRED):**
  - [ ] Add `clonePromptData(for: query, language: String?)` mirroring §3a at `VoxFile+ModelQuery.swift:113`.
  - [ ] `VoxExporter.clonePromptPath(for:)` (`VoxExporter.swift:19`) gains a `language:` segment.
  - [ ] `VoxExporter.addClonePrompt` (`VoxExporter.swift:40`) gains a `language:` param + `"language"` metadata.

---

## 4. Schema Changes

**File to add:** `schemas/manifest-v0.4.0.json` (copy of `manifest-v0.3.0.json` + the change below).

- [ ] In the `embeddings.additionalProperties.properties` object (`manifest-v0.3.0.json:284`), add an optional `language` field:
  ```json
  "language": {
    "type": "string",
    "description": "Language of this embedding/sample in BCP 47 format. Absent = default/language-neutral.",
    "examples": ["en-US", "es", "fr-FR"]
  }
  ```
- [ ] Keep `"additionalProperties": false` inside the embedding object — so `language` MUST be added explicitly (it currently rejects unknown keys at `manifest-v0.3.0.json:283`).
- [ ] Keep the `file` `^embeddings/` pattern (`:299`) — the `<lang>` segment is still under `embeddings/`, so no pattern change needed. ✅
- [ ] Bump `vox_version` examples and `$id`/`title`/`description` to 0.4.0.
- [ ] Update `docs/VOX-FORMAT.md:225-280` (Embedding Metadata section) to document the optional `language` field, the `<lang>` path-segment convention, and the fallback rule. Add a v0.4.0 changelog entry near `docs/VOX-FORMAT.md:198`.

### ⚠️ Pre-existing doc/version drift to fix while here (not caused by this feature)

- [ ] `schemas/README.md:7` says **"current schema version is v0.1.0"** — stale; code is already 0.3.0. Update to 0.4.0.
- [ ] `schemas/validate-examples.sh:20` hard-codes `SCHEMA=".../manifest-v0.1.0.json"` — stale; should point at the current schema (0.4.0 after this change). **The example-validation gate is currently validating against the wrong (oldest) schema.** Fix or the new `language` field won't actually be exercised by CI.

### Version bump decision

Per `CONTRIBUTING.md:29-34`: additive optional fields → **minor bump**. New optional `language` field + new optional path segment is purely additive. → **0.3.0 → 0.4.0** (the project uses 0.x where "minor" = middle digit; this matches the v0.2.0→v0.3.0 precedent which also only added optional fields). **No major/breaking bump required.** Old files validate unchanged because `language` is optional and `additionalProperties:true` at the manifest root.

---

## 5. Swift Type Changes — `VoxManifest.swift`

- [ ] `VoxManifest.EmbeddingEntry` (`VoxManifest.swift:398`): add
  ```swift
  /// Language of this embedding/sample in BCP 47 format (v0.4.0). Nil = default/neutral.
  public var language: String?
  ```
  - Add to `init` (`:414`) with a defaulted `language: String? = nil` — **append it LAST in the parameter list** to avoid breaking existing call sites positionally.
  - `Codable` is synthesized; a new **optional** `var` decodes as `nil` when absent → **backward compatible** (old files have no `language` key, decode fine). New files with `language` are ignored by old readers (they decode the entry and drop the unknown key, since `EmbeddingEntry` would need the field — note: old binaries literally don't have the field, so a *newer file read by an older binary* keeps working because the JSON just carries an extra key the old struct ignores). ✅
  - `EmbeddingEntry` is `Sendable, Equatable` — adding an optional `String?` preserves both. ✅
- [ ] No change to `ReferenceAudio` for the sample-audio feature itself (samples are embeddings, not reference audio). **But** `ReferenceAudio.language` (`VoxManifest.swift:224`) and `Voice.language` (`:118`) already exist — see Decision D5 for reconciliation.

---

## 6. Backward Compatibility

### Old files, new reader
- Old `.vox` has no `language` on any embedding → `language` decodes `nil` → matcher's step-2 default path is taken → **identical to today**. ✅
- Legacy `embeddings/qwen3-tts/sample-audio.wav` fallback (`VoxFile+ModelQuery.swift:157`) is preserved as the final step. ✅
- `VoxMigrator` (`VoxMigrator.swift`) infers entries from binaries; it never sets `language`, leaving migrated entries language-neutral. ✅ No migrator change strictly required, but **add a test** confirming a migrated v0.1.0 file resolves the default sample.

### New file, old reader
- A new file's extra `embeddings/.../es/sample-audio.wav` entry has `language:"es"`. An **old** binary's `EmbeddingEntry` struct lacks the `language` field, so it ignores the key and still resolves the default sample via substring `"sample-audio"` match. **Caveat:** an old reader doing `embeddingData(for:)` could now match the *language-specific* entry first if its key/model substring matches and it happens to be iterated first (dictionary order is nondeterministic). The dedicated `sampleAudioData(for:)`/`clonePromptData(for:)` paths are safe (they don't disambiguate by language, so they return *a* valid sample), but raw `embeddingData(for:)` could return a language sample instead of the default. **Document this as a known, acceptable limitation** — old readers were never language-aware and any valid sample is acceptable for them.

### Old file, old reader
- Untouched. ✅

---

## 7. Decision Log (ambiguities resolved — confirm before coding)

| ID | Question | Recommendation | Rationale |
|----|----------|----------------|-----------|
| **D1** ✅ | `samples/` tree vs `embeddings/` tree? | **LOCKED: `embeddings/` with a `<lang>` segment** | The entire stack (schema `^embeddings/` pattern, reader prefix, `VoxExporter` paths) assumes `embeddings/`. A new tree is a breaking layout change. |
| **D2** ✅ | Audio samples only, or clone-prompts too? | **LOCKED: Both** (clone-prompts mandatory for echada to synthesize per-language) | A per-language *preview* without a per-language *clone prompt* is useless for actual generation. Confirmed by user 2026-06-08. |
| **D3** | Language in PATH, METADATA, or both? | **Metadata field is source of truth; path segment is convention** | The matcher reads `EmbeddingEntry.language`, not the path, so re-pathed files still resolve. Path segment keeps archives human-browsable and keys unique. Writers SHOULD emit both. |
| **D4** | Version bump? | **Minor: 0.3.0 → 0.4.0** | Additive optional field per `CONTRIBUTING.md:29-34`. |
| **D5** | Conflict with existing `Voice.language` / `ReferenceAudio.language`? | **No conflict; they answer different questions** | `Voice.language` = the voice's *primary* language (identity-level). `EmbeddingEntry.language` (new) = which language *this specific sample/embedding* renders. Reuse the SAME BCP 47 convention for consistency. |
| **D6** | BCP 47 vs ISO 639-1? Base-language fallback? | **BCP 47** (e.g. `en-US`, `es`, `fr-FR`) | Every existing `language` field in the format is BCP 47 (`VoxManifest.swift:118,224`; schema `:48,131`; `Voice.language` docs). Consistency wins. **Define base-language fallback**: exact match → base-language match (`fr-FR` query matches stored `fr`) → default. Implement and TEST this precisely; it's easy to get wrong. |

---

## 8. Consumer Surface (what callers must change)

These live in OTHER repos (sibling TODOs own them) but are listed so the API is designed for them:

- **SwiftVoxAlta `VoxImporter.swift:50`** calls `voxFile.sampleAudioData(for: modelQuery)`. To support language, `VoxImportResult` (`VoxImporter.swift:5`) needs a language-aware path or a new `importVox(from:modelQuery:language:)` overload, and `sampleAudioData`/`clonePromptData` fields become language-resolved. **Critical read consumer.**
- **SwiftVoxAlta `VoxExporter.swift:25,40,66`** — the actual writers; add `language:` params (§3b/§3c).
- **SwiftEchada** `CastVoiceGenerator.swift:307`, `VoiceCommand.swift:109`, `TestVoiceCommand.swift:92` call `VoxExporter.addClonePrompt` — these are where per-language clone prompts would be written. **Sibling echada TODO must match the path/metadata scheme chosen here (D1/D3).**
- **`vox` CLI** `Sources/vox/InspectCommand.swift:50` prints voice language — extend `inspect` to list per-embedding languages (uses `sampleAudioLanguages(for:)` from §3a).
- **Produciesta:** no direct `VoxFile`/`sampleAudioData` usage found in `Produciesta/Sources` (greps empty) — it consumes voices via SwiftVoxAlta, so it inherits the importer change transparently.

---

## 9. Test / Fixture / Validation Plan

### Make targets (do NOT run as part of planning)
- `make test` → runs `xcodebuild test -scheme VoxFormat -destination 'platform=macOS,arch=arm64'` (`Makefile:52`).
- `make build` → fast `swift build --product vox` (note: project Makefile uses `swift build` for the dev loop; release/test use xcodebuild). Per global rules, prefer `make` targets / XcodeBuildMCP over raw `swift build`.
- `bash schemas/validate-examples.sh` → validates example manifests (⚠️ currently points at v0.1.0 schema — fix per §4).

### Unit tests to add (Swift, under `implementations/swift/Tests/`)
- [ ] `sampleAudioData(for:language:)` returns exact-language sample when present.
- [ ] Falls back to default sample when requested language absent.
- [ ] Returns `nil` when neither language nor default present (no throw).
- [ ] `language: nil` and `language: "default"` resolve identically to legacy `sampleAudioData(for:)`.
- [ ] Base-language fallback (`fr-FR` query → stored `fr`) per D6.
- [ ] `deriveEmbeddingKey` produces distinct keys for default vs `<lang>` paths (no overwrite).
- [ ] Old v0.1.0/v0.3.0 fixture (no `language`) resolves exactly as before (regression).
- [ ] Round-trip: write entry with `language`, read back, assert `EmbeddingEntry.language` survives.
- [ ] (If D2) same battery for `clonePromptData(for:language:)`.

### Example fixtures
- [ ] Add `examples/multi-language/` with a `.vox` carrying a default + at least one `<lang>` sample, plus `manifest.json` and an `examples/README.md` entry (`CONTRIBUTING.md:44-52` checklist).
- [ ] Existing example `.vox` files (`examples/multi-model/`, `examples/minimal/`, `examples/character/`) need NO change — they stay valid (additive field). Confirm they still validate against the new 0.4.0 schema in `validate-examples.sh`.
- [ ] Python implementation (`implementations/python/`) — mirror the optional `language` field in its manifest dataclass + tests, or explicitly defer with a tracking note (it must still *read* new files without error; it already tolerates unknown keys if it doesn't use strict schemas — verify `test_manifest_decoding.py`).

---

## 10. Remaining Refinements (non-blocking — defaults adopted, override if desired)

The two scope-defining blockers (D1 path scheme, D2 clone-prompts-too) are **RESOLVED** — see Decisions Locked at top. These remaining items have adopted defaults and do NOT block starting work:

1. ~~D2 scope~~ — **RESOLVED: clone prompts + samples.**
2. ~~D1 path scheme~~ — **RESOLVED: `embeddings/<engine>/<slug>/<lang>/...`.**
3. **D6 fallback granularity (default adopted):** implement exact-match → **base-language fallback** (`fr-FR` query matches stored `fr`) → default → nil. This is the recommended behavior; flagged only because it's easy to get wrong — TEST it precisely.
4. **Python parity (default adopted):** mirror the optional `language` field in the Python manifest dataclass + ensure it *reads* a `multi-language` example without error. If that proves heavy, defer with a tracking note — but the new `examples/multi-language/.vox` will force Python to at least decode it (`CONTRIBUTING.md:81`).
5. **Default-language identity (default adopted):** keep the default (language-less) sample untagged even when `Voice.language` is set — do NOT auto-tag it, so the fallback rule stays simple.
