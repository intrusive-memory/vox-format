import Foundation

/// A parsed VOX voice identity file.
///
/// Represents the complete contents of a `.vox` archive, including the manifest metadata,
/// reference audio file locations, and optional extensions directory. This struct is returned
/// by ``VoxReader/read(from:)`` and consumed by ``VoxWriter/write(_:to:)``.
public struct VoxFile {
    /// The parsed manifest containing voice identity metadata.
    public let manifest: VoxManifest

    /// URLs to reference audio files extracted from the archive.
    ///
    /// These point to temporary file locations after reading. When creating a new `VoxFile`
    /// for writing, these should point to the source audio files on disk.
    public let referenceAudioURLs: [URL]

    /// URL to the extensions directory within the extracted archive, if present.
    ///
    /// Engine-specific binary data (embeddings, model weights) lives here,
    /// organized by provider namespace (e.g., `embeddings/qwen3-tts/`).
    public let extensionsDirectory: URL?

    /// Creates a new VoxFile with the given manifest and file references.
    ///
    /// - Parameters:
    ///   - manifest: The voice identity manifest.
    ///   - referenceAudioURLs: URLs to reference audio files.
    ///   - extensionsDirectory: URL to the extensions/embeddings directory, if any.
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
