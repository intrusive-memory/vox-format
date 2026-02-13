import Foundation

/// A parsed VOX voice identity file representing the complete contents of a `.vox` archive.
///
/// `VoxFile` is an immutable container that holds the decoded manifest metadata, resolved
/// reference audio file locations, and an optional extensions directory. It serves as the
/// primary exchange type between ``VoxReader`` (which produces instances by parsing archives)
/// and ``VoxWriter`` (which consumes instances to create archives).
///
/// ```swift
/// // Reading
/// let reader = VoxReader()
/// let voxFile = try reader.read(from: URL(fileURLWithPath: "voice.vox"))
/// print(voxFile.manifest.voice.name)
///
/// // Writing
/// let writer = VoxWriter()
/// try writer.write(voxFile, to: URL(fileURLWithPath: "copy.vox"))
/// ```
public struct VoxFile {
    /// The parsed manifest containing all voice identity metadata.
    public let manifest: VoxManifest

    /// URLs to reference audio files extracted from or destined for the archive.
    ///
    /// After reading, these point to temporary file locations in the extracted archive.
    /// When creating a new `VoxFile` for writing, these should point to the source
    /// audio files on disk that will be bundled into the `reference/` directory.
    public let referenceAudioURLs: [URL]

    /// URL to the extensions directory within the extracted archive, if present.
    ///
    /// Engine-specific binary data (embeddings, model weights) lives in the
    /// `embeddings/` directory, organized by provider namespace
    /// (e.g., `embeddings/qwen3-tts/`).
    public let extensionsDirectory: URL?

    /// Creates a new `VoxFile` with the given manifest and file references.
    ///
    /// - Parameters:
    ///   - manifest: The voice identity manifest containing all metadata.
    ///   - referenceAudioURLs: URLs to reference audio files to include in the archive.
    ///     Defaults to an empty array.
    ///   - extensionsDirectory: URL to a directory containing engine-specific extension
    ///     data, or `nil` if no extensions are present. Defaults to `nil`.
    public init(
        manifest: VoxManifest,
        referenceAudioURLs: [URL] = [],
        extensionsDirectory: URL? = nil
    ) {
        self.manifest = manifest
        self.referenceAudioURLs = referenceAudioURLs
        self.extensionsDirectory = extensionsDirectory
    }
}
