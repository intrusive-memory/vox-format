import Foundation

/// A parsed VOX voice identity file representing the complete contents of a `.vox` archive.
///
/// `VoxFile` is an immutable, in-memory container that holds the decoded manifest metadata,
/// reference audio data, and engine-specific embeddings. It serves as the primary exchange
/// type between ``VoxReader`` (which produces instances by parsing archives) and
/// ``VoxWriter`` (which consumes instances to create archives).
///
/// All binary data is held in memory — no temporary files or directories are needed.
///
/// ```swift
/// // Reading
/// let reader = VoxReader()
/// let voxFile = try reader.read(from: URL(fileURLWithPath: "voice.vox"))
/// print(voxFile.manifest.voice.name)
///
/// // Accessing embeddings
/// if let clonePrompt = voxFile.embeddings["qwen3-tts/clone-prompt.bin"] {
///     // Use the binary data directly
/// }
///
/// // Writing
/// let writer = VoxWriter()
/// try writer.write(voxFile, to: URL(fileURLWithPath: "copy.vox"))
/// ```
public struct VoxFile {
    /// The parsed manifest containing all voice identity metadata.
    public let manifest: VoxManifest

    /// Reference audio data keyed by filename (e.g. `"sample-01.wav"` → audio bytes).
    ///
    /// When reading, filenames are extracted from the `reference/` directory in the archive.
    /// When writing, each entry is written to `reference/<filename>` in the archive.
    public let referenceAudio: [String: Data]

    /// Engine-specific embedding data keyed by path relative to `embeddings/`.
    ///
    /// For example, a Qwen3-TTS clone prompt would be stored as:
    /// `"qwen3-tts/clone-prompt.bin"` → binary data
    ///
    /// When reading, entries are extracted from the `embeddings/` directory in the archive.
    /// When writing, each entry is written to `embeddings/<key>` in the archive.
    public let embeddings: [String: Data]

    /// Whether this voice file has everything needed for synthesis.
    public enum Readiness: Equatable, Sendable {
        /// All declared embeddings and reference audio are present.
        case ready
        /// Embeddings are missing but can be regenerated from voice description + reference audio.
        case needsRegeneration(missing: [String])
        /// The file has fundamental problems (no voice description, invalid manifest).
        case invalid(reasons: [String])
    }

    /// Assesses whether this VoxFile is complete and ready for synthesis.
    public var readiness: Readiness {
        var reasons: [String] = []

        // Fundamental checks
        let descLength = manifest.voice.description.trimmingCharacters(in: .whitespaces).count
        if descLength < 10 {
            reasons.append("Voice description is too short (\(descLength) chars, need >= 10)")
        }
        if manifest.voice.name.trimmingCharacters(in: .whitespaces).isEmpty {
            reasons.append("Voice name is empty")
        }

        if !reasons.isEmpty {
            return .invalid(reasons: reasons)
        }

        var missingEmbeddings: [String] = []

        // Check each declared embedding entry has its binary
        if let entries = manifest.embeddingEntries {
            for (key, entry) in entries {
                let relativePath = entry.file.hasPrefix("embeddings/")
                    ? String(entry.file.dropFirst("embeddings/".count))
                    : entry.file
                if embeddings[relativePath] == nil {
                    missingEmbeddings.append(key)
                }
            }
        }

        // Check each declared reference audio has its data
        if let refAudioEntries = manifest.referenceAudio {
            for entry in refAudioEntries {
                let filename: String
                if entry.file.hasPrefix("reference/") {
                    filename = String(entry.file.dropFirst("reference/".count))
                } else {
                    filename = entry.file
                }
                if referenceAudio[filename] == nil {
                    // Missing reference audio is more serious but still flaggable
                    missingEmbeddings.append("reference:\(entry.file)")
                }
            }
        }

        if missingEmbeddings.isEmpty {
            return .ready
        }
        return .needsRegeneration(missing: missingEmbeddings)
    }

    /// Convenience: `true` when `readiness == .ready`.
    public var isReady: Bool {
        readiness == .ready
    }

    /// Convenience: `true` when readiness is `.needsRegeneration`.
    public var needsRegeneration: Bool {
        if case .needsRegeneration = readiness { return true }
        return false
    }

    /// Creates a new `VoxFile` with the given manifest and data.
    ///
    /// - Parameters:
    ///   - manifest: The voice identity manifest containing all metadata.
    ///   - referenceAudio: Reference audio data keyed by filename. Defaults to empty.
    ///   - embeddings: Engine-specific embedding data keyed by relative path. Defaults to empty.
    public init(
        manifest: VoxManifest,
        referenceAudio: [String: Data] = [:],
        embeddings: [String: Data] = [:]
    ) {
        self.manifest = manifest
        self.referenceAudio = referenceAudio
        self.embeddings = embeddings
    }
}
