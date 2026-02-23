import Foundation

// MARK: - Auto-Manifest Sync

extension VoxFile {

    /// Adds a manifest entry corresponding to the given VoxEntry.
    ///
    /// - `reference/` prefix → creates/updates `manifest.referenceAudio`
    /// - `embeddings/` prefix → creates/updates `manifest.embeddingEntries` (requires `model` metadata)
    /// - Other paths → no manifest effect
    internal func addManifestEntry(for entry: VoxEntry) {
        if entry.path.hasPrefix("reference/") {
            addReferenceAudioManifestEntry(for: entry)
        } else if entry.path.hasPrefix("embeddings/") {
            addEmbeddingManifestEntry(for: entry)
        }
    }

    /// Removes the manifest entry corresponding to the given archive path.
    internal func removeManifestEntry(for path: String) {
        if path.hasPrefix("reference/") {
            manifest.referenceAudio?.removeAll { $0.file == path }
            if manifest.referenceAudio?.isEmpty == true {
                manifest.referenceAudio = nil
            }
        } else if path.hasPrefix("embeddings/") {
            if var entries = manifest.embeddingEntries {
                // Remove any entry whose file matches this path.
                let keysToRemove = entries.filter { $0.value.file == path }.map(\.key)
                for key in keysToRemove {
                    entries.removeValue(forKey: key)
                }
                manifest.embeddingEntries = entries.isEmpty ? nil : entries
            }
        }
    }

    // MARK: - Private Helpers

    private func addReferenceAudioManifestEntry(for entry: VoxEntry) {
        let transcript = entry.metadata["transcript"] as? String ?? ""
        let language = entry.metadata["language"] as? String
        let duration = entry.metadata["duration_seconds"] as? Double
        let context = entry.metadata["context"] as? String
        let model = entry.metadata["model"] as? String
        let engine = entry.metadata["engine"] as? String

        let refAudio = VoxManifest.ReferenceAudio(
            file: entry.path,
            transcript: transcript,
            language: language,
            durationSeconds: duration,
            context: context,
            model: model,
            engine: engine
        )

        // Replace if an entry for this file already exists.
        if var existing = manifest.referenceAudio {
            if let idx = existing.firstIndex(where: { $0.file == entry.path }) {
                existing[idx] = refAudio
            } else {
                existing.append(refAudio)
            }
            manifest.referenceAudio = existing
        } else {
            manifest.referenceAudio = [refAudio]
        }
    }

    private func addEmbeddingManifestEntry(for entry: VoxEntry) {
        let model = entry.metadata["model"] as? String ?? ""
        let engine = entry.metadata["engine"] as? String
        let format = entry.metadata["format"] as? String
        let description = entry.metadata["description"] as? String
        let key = entry.metadata["key"] as? String ?? deriveEmbeddingKey(from: entry.path)

        let embeddingEntry = VoxManifest.EmbeddingEntry(
            model: model,
            engine: engine,
            file: entry.path,
            format: format,
            description: description
        )

        if manifest.embeddingEntries == nil {
            manifest.embeddingEntries = [:]
        }
        manifest.embeddingEntries?[key] = embeddingEntry
    }

    /// Derives a human-readable key from an embedding path.
    /// e.g., `"embeddings/qwen3-tts/0.6b/clone-prompt.bin"` → `"qwen3-tts-0.6b"`
    private func deriveEmbeddingKey(from path: String) -> String {
        let stripped = path.hasPrefix("embeddings/")
            ? String(path.dropFirst("embeddings/".count))
            : path
        let components = stripped.split(separator: "/").map(String.init)
        let dirs = components.dropLast()
        if dirs.isEmpty {
            return (stripped as NSString).deletingPathExtension
        }
        return dirs.joined(separator: "-")
    }
}
