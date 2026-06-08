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

    /// Returns clone prompt data for the given model query, if present.
    ///
    /// Searches embedding entries for a clone-prompt file matching the model query.
    /// Falls back to the legacy `embeddings/qwen3-tts/clone-prompt.bin` path.
    ///
    /// Unlike ``embeddingData(for:)``, this method only matches entries whose file
    /// path contains `"clone-prompt"`, avoiding ambiguity when both clone prompts
    /// and sample audio exist for the same model.
    ///
    /// - Parameter query: A model identifier or substring (e.g., "0.6b", "1.7b").
    /// - Returns: Clone prompt binary data, or nil if no clone prompt exists for this model.
    public func clonePromptData(for query: String) -> Data? {
        clonePromptData(for: query, language: nil)
    }

    /// Returns clone prompt data for the given model and language, with fallback (v0.4.0).
    ///
    /// Resolution order for a `(model, language)` lookup:
    /// 1. An embedding whose `language` matches `language` exactly (case-insensitive).
    /// 2. The base-language match (a query of `"fr-FR"` matches a stored `"fr"`).
    /// 3. The default / language-neutral embedding (`language == nil`).
    /// 4. The legacy `embeddings/qwen3-tts/clone-prompt.bin` path.
    ///
    /// Passing `language` as `nil` or `"default"` resolves only the default/language-neutral
    /// embedding (then legacy), behaving identically to ``clonePromptData(for:)``.
    ///
    /// - Parameters:
    ///   - query: A model identifier or substring (e.g., "0.6b", "1.7b").
    ///   - language: A BCP 47 language tag (e.g., "es", "fr-FR"), or `nil`/`"default"`.
    /// - Returns: Clone prompt binary data, or nil if none resolves.
    public func clonePromptData(for query: String, language: String?) -> Data? {
        embeddingData(
            fileContaining: "clone-prompt",
            query: query,
            language: language,
            legacyPath: "embeddings/qwen3-tts/clone-prompt.bin"
        )
    }

    /// Returns sample audio data for the given model query, if present.
    ///
    /// Searches embedding entries for a sample-audio file matching the model query.
    /// Falls back to the legacy `embeddings/qwen3-tts/sample-audio.wav` path.
    ///
    /// - Parameter query: A model identifier or substring (e.g., "0.6b", "1.7b").
    /// - Returns: WAV audio data, or nil if no sample audio exists for this model.
    public func sampleAudioData(for query: String) -> Data? {
        sampleAudioData(for: query, language: nil)
    }

    /// Returns sample audio data for the given model and language, with fallback (v0.4.0).
    ///
    /// Resolution order for a `(model, language)` lookup:
    /// 1. An embedding whose `language` matches `language` exactly (case-insensitive).
    /// 2. The base-language match (a query of `"fr-FR"` matches a stored `"fr"`).
    /// 3. The default / language-neutral embedding (`language == nil`).
    /// 4. The legacy `embeddings/qwen3-tts/sample-audio.wav` path.
    ///
    /// Passing `language` as `nil` or `"default"` resolves only the default/language-neutral
    /// embedding (then legacy), behaving identically to ``sampleAudioData(for:)``.
    ///
    /// - Parameters:
    ///   - query: A model identifier or substring (e.g., "0.6b", "1.7b").
    ///   - language: A BCP 47 language tag (e.g., "es", "fr-FR"), or `nil`/`"default"`.
    /// - Returns: WAV audio data, or nil if none resolves.
    public func sampleAudioData(for query: String, language: String?) -> Data? {
        embeddingData(
            fileContaining: "sample-audio",
            query: query,
            language: language,
            legacyPath: "embeddings/qwen3-tts/sample-audio.wav"
        )
    }

    /// Languages for which a sample-audio embedding exists for the given model (v0.4.0).
    ///
    /// Only language-specific samples are listed; the default/language-neutral sample is
    /// not represented (an empty result means "default only" or "no samples"). Consumers
    /// use this to discover what languages a voice ships before requesting one.
    ///
    /// - Parameter query: A model identifier or substring (e.g., "0.6b", "1.7b").
    /// - Returns: Sorted, de-duplicated BCP 47 language tags as stored on the entries.
    public func sampleAudioLanguages(for query: String) -> [String] {
        embeddingLanguages(fileContaining: "sample-audio", query: query)
    }

    /// Languages for which a clone-prompt embedding exists for the given model (v0.4.0).
    ///
    /// See ``sampleAudioLanguages(for:)`` for semantics.
    public func clonePromptLanguages(for query: String) -> [String] {
        embeddingLanguages(fileContaining: "clone-prompt", query: query)
    }

    // MARK: - Private Language-Aware Resolution

    /// Resolves embedding data by file-substring, model query, and language with fallback.
    ///
    /// Implements the §1 / D6 fallback chain: exact language → base-language → default
    /// (language-neutral) → legacy path. See ``sampleAudioData(for:language:)``.
    private func embeddingData(
        fileContaining substring: String,
        query: String,
        language: String?,
        legacyPath: String
    ) -> Data? {
        guard let entries = manifest.embeddingEntries else {
            // No embedding entries; check legacy path
            return self[legacyPath]?.data
        }
        let q = query.lowercased()

        // Candidate entry-languages to try, in priority order. `nil` = language-neutral.
        let candidates = languageCandidates(for: language)

        for candidate in candidates {
            for (key, entry) in entries {
                guard entry.file.contains(substring) else { continue }
                guard key.lowercased().contains(q) || entry.model.lowercased().contains(q) else { continue }
                if entryLanguage(entry, matches: candidate) {
                    return self[entry.file]?.data
                }
            }
        }

        // Fall back to legacy path
        return self[legacyPath]?.data
    }

    /// All distinct language tags (as stored) for matching embeddings of a given kind.
    private func embeddingLanguages(fileContaining substring: String, query: String) -> [String] {
        guard let entries = manifest.embeddingEntries else { return [] }
        let q = query.lowercased()
        var seen = Set<String>()
        var result: [String] = []
        for (key, entry) in entries {
            guard entry.file.contains(substring) else { continue }
            guard key.lowercased().contains(q) || entry.model.lowercased().contains(q) else { continue }
            guard let lang = entry.language else { continue }
            if seen.insert(lang.lowercased()).inserted {
                result.append(lang)
            }
        }
        return result.sorted()
    }

    /// Ordered list of candidate entry-languages for a requested `language`.
    ///
    /// - `nil` / `"default"` → `[nil]` (default/language-neutral only — legacy behavior).
    /// - `"fr-FR"` → `["fr-fr", "fr", nil]` (exact → base-language → default).
    /// - `"es"` → `["es", nil]` (exact → default).
    private func languageCandidates(for language: String?) -> [String?] {
        guard let language, language.lowercased() != "default" else {
            return [nil]
        }
        let lang = language.lowercased()
        var candidates: [String?] = [lang]
        if let dash = lang.firstIndex(of: "-") {
            let base = String(lang[lang.startIndex..<dash])
            if !base.isEmpty, base != lang {
                candidates.append(base)
            }
        }
        candidates.append(nil)
        return candidates
    }

    /// Whether an entry's stored language matches a candidate (case-insensitive; `nil` == neutral).
    private func entryLanguage(_ entry: VoxManifest.EmbeddingEntry, matches candidate: String?) -> Bool {
        switch (entry.language, candidate) {
        case (nil, nil):
            return true
        case let (stored?, wanted?):
            return stored.lowercased() == wanted
        default:
            return false
        }
    }
}
