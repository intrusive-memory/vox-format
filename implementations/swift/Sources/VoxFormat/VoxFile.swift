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
