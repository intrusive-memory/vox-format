import Foundation

// MARK: - Model Query

extension VoxFile {

    /// Whether this voice has an embedding compatible with the given query.
    ///
    /// Matching is flexible: the query is checked against embedding keys and model
    /// identifiers using case-insensitive substring matching.
    ///
    /// - Parameter query: A model identifier, key, or substring (e.g., `"0.6b"`,
    ///   `"Qwen/Qwen3-TTS-12Hz-0.6B"`, `"qwen3-tts-0.6b"`).
    /// - Returns: `true` if a matching embedding entry exists.
    public func supportsModel(_ query: String) -> Bool {
        embeddingEntry(for: query) != nil
    }

    /// Returns the ``VoxManifest/EmbeddingEntry`` matching the given query, if any.
    ///
    /// Match priority:
    /// 1. Exact key match
    /// 2. Case-insensitive exact key match
    /// 3. Case-insensitive model contains query
    /// 4. Case-insensitive key contains query
    ///
    /// - Parameter query: A model identifier, key, or substring.
    /// - Returns: The first matching entry, or `nil`.
    public func embeddingEntry(for query: String) -> VoxManifest.EmbeddingEntry? {
        guard let entries = manifest.embeddingEntries else { return nil }
        let q = query.lowercased()

        // 1. Exact key match
        if let entry = entries[query] {
            return entry
        }

        // 2. Case-insensitive exact key match
        for (key, entry) in entries {
            if key.lowercased() == q {
                return entry
            }
        }

        // 3. Case-insensitive model contains query
        for (_, entry) in entries {
            if entry.model.lowercased().contains(q) {
                return entry
            }
        }

        // 4. Case-insensitive key contains query
        for (key, entry) in entries {
            if key.lowercased().contains(q) {
                return entry
            }
        }

        return nil
    }

    /// Returns the raw binary data for the embedding matching the given query.
    ///
    /// This resolves the entry's `file` path against the container's stored entries.
    ///
    /// - Parameter query: A model identifier, key, or substring.
    /// - Returns: The embedding binary data, or `nil` if not found.
    public func embeddingData(for query: String) -> Data? {
        guard let entry = embeddingEntry(for: query) else { return nil }
        return self[entry.file]?.data
    }

    /// All model identifiers declared in this voice's embedding entries.
    public var supportedModels: [String] {
        manifest.embeddingEntries?.values.map(\.model) ?? []
    }

    /// Returns reference audio clips matching the given model, falling back to universal clips.
    ///
    /// A clip matches if its `model` field contains the query (case-insensitive substring).
    /// If no model-matched clips exist, returns clips without a `model` tag (universal clips).
    ///
    /// - Parameter model: A model identifier or substring (e.g., `"0.6b"`, `"Qwen/Qwen3-TTS-12Hz-1.7B"`).
    /// - Returns: Matching reference audio entries. May be empty if no clips exist at all.
    public func referenceAudio(for model: String) -> [VoxManifest.ReferenceAudio] {
        guard let clips = manifest.referenceAudio else { return [] }
        let q = model.lowercased()

        let matched = clips.filter { clip in
            guard let clipModel = clip.model else { return false }
            return clipModel.lowercased().contains(q)
        }

        if !matched.isEmpty {
            return matched
        }

        // Fall back to universal (untagged) clips
        return clips.filter { $0.model == nil }
    }
}
