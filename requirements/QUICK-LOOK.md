# VOX Quick Look Plugin — Requirements

**Status:** Proposed  
**Version:** 0.1  
**Target Platform:** macOS 13+

---

## Overview

A macOS Quick Look extension that previews `.vox` files directly in Finder (Space bar) and other Quick Look contexts. The preview renders voice identity metadata and, when reference audio is embedded in the container, presents a playable audio clip with transcript.

The goal is to make `.vox` files first-class filesystem citizens — immediately identifiable and previewable without launching any app.

---

## Deliverables

| Artifact | Description |
|---|---|
| `VoxQuickLook.appex` | Quick Look App Extension |
| Host macOS app | Thin wrapper required by macOS extension model; registers the UTI |
| UTI declaration | `com.intrusive-memory.vox` mapped to `.vox` extension |
| Finder thumbnail | Compact icon generated from voice name and metadata |

---

## Platform and Distribution Requirements

- **Minimum macOS:** 13.0 (Ventura)
- **Extension model:** App Extension (`NSExtensionPointIdentifier: com.apple.quicklook.preview`)
- **Host app requirement:** The extension must live inside an `.app` bundle. A minimal stub app suffices for v1. The host app is what registers the UTI with the system; without it, Finder will not associate `.vox` files with the extension.
- **Sandbox:** The extension runs sandboxed. No network access. Reads only the file passed by Quick Look.
- **Distribution:** Mac App Store or direct download (notarized). The host app installs to `/Applications`; the extension is embedded inside it.

---

## File Type Registration

### UTI Declaration (host app `Info.plist`)

```xml
<key>UTExportedTypeDeclarations</key>
<array>
  <dict>
    <key>UTTypeIdentifier</key>
    <string>com.intrusive-memory.vox</string>
    <key>UTTypeDescription</key>
    <string>VOX Voice Identity</string>
    <key>UTTypeConformsTo</key>
    <array>
      <string>public.zip-archive</string>
    </array>
    <key>UTTypeTagSpecification</key>
    <dict>
      <key>public.filename-extension</key>
      <array>
        <string>vox</string>
      </array>
    </dict>
  </dict>
</array>
```

The extension's `Info.plist` declares the same UTI under `QLSupportedContentTypes`.

**Note:** `.vox` has a historical association with Dialogic ADPCM audio (unrelated format, no ZIP magic bytes). The UTI conformance to `public.zip-archive` and the magic byte check on the ZIP header provide unambiguous disambiguation.

---

## Preview Panel Requirements

### Layout

The preview is a single scrollable panel rendered via SwiftUI inside `QLPreviewingController`. It is divided into three sections, rendered in order:

```
┌─────────────────────────────────────────────┐
│  VOICE NAME                    [tag] [tag]  │
│  voice description text (wrapping)          │
├─────────────────────────────────────────────┤
│  AUDIO PLAYER  (if reference audio exists)  │
│  ▶  ────────────────────────  0:04          │
│  "Transcript text of the audio clip..."     │
│  [clip 2] [clip 3]  (if multiple)           │
├─────────────────────────────────────────────┤
│  METADATA GRID                              │
│  Language    en-GB                          │
│  Gender      male                           │
│  Age range   45 – 55                        │
│  Pitch       low / moderate range           │
│  Rate        moderate                       │
│  Energy      medium                         │
│  Provenance  designed (qwen3-tts)           │
│  License     CC0-1.0                        │
│  Engines     qwen3-tts, elevenlabs          │
└─────────────────────────────────────────────┘
```

### Section 1 — Voice Identity Header

| Field | Source | Required |
|---|---|---|
| Voice name | `manifest.voice.name` | Always shown |
| Description | `manifest.voice.description` | Always shown |
| Tags | `manifest.voice.tags[]` | Shown as pill badges if present |
| Language | `manifest.voice.language` | Shown inline with name if present |

### Section 2 — Audio Player

Shown only when `manifest.reference_audio` is non-empty and at least one referenced file exists in the ZIP archive.

**Behavior:**
- Extract the first `reference_audio` entry whose `file` path resolves to a ZIP entry.
- Write the audio data to a temporary file (`FileManager.default.temporaryDirectory`).
- Play via `AVAudioPlayer`.
- Do **not** auto-play. Show a play/pause button.
- Show clip duration (from `duration_seconds` if present in manifest; otherwise from `AVAudioPlayer.duration`).
- Show transcript text below the waveform bar if `transcript` is present in the manifest entry.
- If multiple clips are present, show a horizontal clip selector (labeled by index or `context` field if available). Selecting a clip loads and cues it without auto-playing.

**If no reference audio is present or extractable:**  
Render a placeholder row: `"No reference audio"` with a microphone-off icon. Do not show an empty player widget.

### Section 3 — Metadata Grid

Show any of the following fields that are present in the manifest. Omit rows for absent fields entirely.

| Label | Source |
|---|---|
| Language | `manifest.voice.language` |
| Gender | `manifest.voice.gender` |
| Age range | `manifest.voice.age_range` formatted as `{min} – {max}` |
| Pitch | `manifest.prosody.pitch_base` + `manifest.prosody.pitch_range` |
| Rate | `manifest.prosody.rate` |
| Energy | `manifest.prosody.energy` |
| Default emotion | `manifest.prosody.emotion_default` |
| Character role | `manifest.character.role` (truncated to 2 lines) |
| Provenance | `manifest.provenance.method` + `manifest.provenance.engine` if present |
| Consent | `manifest.provenance.consent` |
| License | `manifest.provenance.license` |
| Engines | Unique `engine` values from `manifest.reference_audio[]` and `manifest.embeddings[]`, de-duped |
| Created | `manifest.created` formatted as locale date |
| VOX version | `manifest.vox_version` |

---

## Thumbnail Requirements

The Quick Look extension also provides a Finder thumbnail (the file icon shown in icon view and cover flow).

**Design:**
- Background: a solid color derived by hashing `manifest.id` into a limited palette of muted colors
- Center: voice name in bold, truncated to ~2 lines
- Bottom strip: language code (e.g., `en-GB`) and a waveform icon if reference audio is present

**Implementation:** Render a SwiftUI view into a `CGImage` via `ImageRenderer` (macOS 13+) and return it from `QLThumbnailProvider`.

---

## Implementation Architecture

### Dependencies

- **`VoxFormat`** (this repo, `implementations/swift/`) — `VoxFile(contentsOf:)` for reading the container and manifest. Eliminates any need for manual ZIP handling.
- **`AVFoundation`** — audio playback
- **`SwiftUI`** — preview UI and thumbnail rendering

### Entry Points

```swift
// Preview
class PreviewViewController: NSViewController, QLPreviewingController {
    func preparePreviewOfFile(at url: URL) async throws {
        let vox = try VoxFile(contentsOf: url)
        // build SwiftUI view from vox.manifest and vox.entries(under: "reference/")
    }
}

// Thumbnail
class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        // render SwiftUI thumbnail view to CGImage
    }
}
```

### Audio Extraction

```swift
// Extract first playable reference audio entry
func firstAudioEntry(in vox: VoxFile) -> (entry: VoxEntry, meta: ReferenceAudio)? {
    guard let audioMeta = vox.manifest.referenceAudio?.first else { return nil }
    guard let entry = vox[audioMeta.file] else { return nil }
    return (entry, audioMeta)
}

// Write to temp file for AVAudioPlayer
let tmp = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension(entry.path.pathExtension)
try entry.data.write(to: tmp)
let player = try AVAudioPlayer(contentsOf: tmp)
```

Temp files are cleaned up when the preview controller is deallocated.

---

## Error and Degradation Handling

| Condition | Behavior |
|---|---|
| Valid manifest, no reference audio | Show header + metadata grid; show "No reference audio" placeholder |
| Valid manifest, audio entry missing from ZIP | Show manifest data; suppress audio section; log warning (no user-visible error) |
| Corrupt or unreadable ZIP | Show error state: "Unable to read VOX file" with the specific `VoxError` message |
| Manifest missing required fields | Show whatever is available; show "Incomplete VOX file" badge |
| Audio data present but unplayable | Show transcript-only row where player would appear |

---

## Out of Scope (v1)

- **On-demand TTS synthesis** — generating audio for voices without reference clips requires a local TTS engine and is not sandboxable without significant entitlement work. Defer to v2.
- **Network requests** — plugin runs fully offline.
- **Library browser** — browsing a voice library folder. This belongs in a future companion app, not a Quick Look plugin.
- **Waveform visualization** — a scrolling waveform during playback is a nice-to-have; a simple progress bar is sufficient for v1.
- **Editing** — Quick Look is read-only by design.

---

## Open Questions

1. **Host app identity:** Should the host app be a standalone "VOX Viewer" utility, or should it live inside a future larger app (e.g., a SwiftVoxAlta companion)? Answer determines the bundle ID and App Store placement.
2. **Auto-play preference:** Should there be a user preference (stored in `UserDefaults` in an app group) to auto-play the first clip? Or is manual play always safer?
3. **Multiple clip UX:** For voices with 5+ reference clips, does a horizontal scroller work, or is a compact list better?

---

**Last Updated:** 2026-04-08
