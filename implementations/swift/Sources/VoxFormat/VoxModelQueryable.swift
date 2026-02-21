import Foundation

/// A type that can be queried for model-specific embedding support.
///
/// `VoxModelQueryable` provides a uniform API for asking whether a voice identity
/// supports a particular TTS model, retrieving embedding metadata, and accessing
/// the raw binary data for a model's embedding.
///
/// ```swift
/// let vox = try VoxReader().read(from: url)
/// if vox.supportsModel("0.6b") {
///     let data = vox.embeddingData(for: "0.6b")
/// }
/// ```
public protocol VoxModelQueryable {
    /// Whether this voice has an embedding compatible with the given query.
    ///
    /// Matching is flexible: the query is checked against embedding keys and model
    /// identifiers using case-insensitive substring matching.
    ///
    /// - Parameter query: A model identifier, key, or substring (e.g., `"0.6b"`,
    ///   `"Qwen/Qwen3-TTS-12Hz-0.6B"`, `"qwen3-tts-0.6b"`).
    /// - Returns: `true` if a matching embedding entry exists.
    func supportsModel(_ query: String) -> Bool

    /// Returns the ``VoxManifest/EmbeddingEntry`` matching the given query, if any.
    ///
    /// - Parameter query: A model identifier, key, or substring.
    /// - Returns: The first matching entry, or `nil`.
    func embeddingEntry(for query: String) -> VoxManifest.EmbeddingEntry?

    /// Returns the raw binary data for the embedding matching the given query.
    ///
    /// This resolves the entry's `file` path against the archive's `embeddings` data.
    ///
    /// - Parameter query: A model identifier, key, or substring.
    /// - Returns: The embedding binary data, or `nil` if not found.
    func embeddingData(for query: String) -> Data?

    /// All model identifiers declared in this voice's embedding entries.
    var supportedModels: [String] { get }
}

// MARK: - VoxFile + VoxModelQueryable

extension VoxFile: VoxModelQueryable {
    public func supportsModel(_ query: String) -> Bool {
        embeddingEntry(for: query) != nil
    }

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

    public func embeddingData(for query: String) -> Data? {
        guard let entry = embeddingEntry(for: query) else { return nil }

        // The entry's file path is archive-relative (e.g., "embeddings/qwen3-tts/0.6b/clone-prompt.bin").
        // VoxFile.embeddings keys are relative to embeddings/ (e.g., "qwen3-tts/0.6b/clone-prompt.bin").
        let filePath = entry.file
        let prefix = "embeddings/"
        let key: String
        if filePath.hasPrefix(prefix) {
            key = String(filePath.dropFirst(prefix.count))
        } else {
            key = filePath
        }

        return embeddings[key]
    }

    public var supportedModels: [String] {
        manifest.embeddingEntries?.values.map(\.model) ?? []
    }
}
