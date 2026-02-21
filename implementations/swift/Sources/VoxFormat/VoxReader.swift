import Foundation
import ZIPFoundation

/// Reads and parses `.vox` voice identity archives directly into memory.
///
/// `VoxReader` opens a `.vox` ZIP archive and reads entries directly into `Data`
/// without extracting to disk. The manifest is decoded, reference audio and embeddings
/// are read into memory, and a fully populated ``VoxFile`` is returned.
///
/// ```swift
/// let reader = VoxReader()
/// let voxFile = try reader.read(from: URL(fileURLWithPath: "voice.vox"))
/// print(voxFile.manifest.voice.name)
/// if let prompt = voxFile.embeddings["qwen3-tts/clone-prompt.bin"] {
///     print("Clone prompt: \(prompt.count) bytes")
/// }
/// ```
public final class VoxReader {

    /// Creates a new `VoxReader` instance.
    public init() {}

    /// Reads a `.vox` archive and returns a fully populated ``VoxFile``.
    ///
    /// All data is read directly into memory — no temporary files are created.
    ///
    /// - Parameter url: The file URL of the `.vox` archive to read.
    /// - Returns: A ``VoxFile`` containing the parsed manifest, reference audio, and embeddings.
    /// - Throws: ``VoxError/invalidZipFile(_:underlying:)`` if the file is not a valid ZIP archive.
    /// - Throws: ``VoxError/manifestNotFound(_:)`` if `manifest.json` is missing.
    /// - Throws: ``VoxError/invalidJSON(_:underlying:)`` if `manifest.json` cannot be decoded.
    public func read(from url: URL) throws -> VoxFile {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw VoxError.invalidZipFile(url)
        }

        // Collect all entries into memory, keyed by archive path.
        var entries: [String: Data] = [:]
        for entry in archive where entry.type == .file {
            var entryData = Data()
            _ = try archive.extract(entry) { chunk in
                entryData.append(chunk)
            }
            entries[entry.path] = entryData
        }

        // Step 1: Parse manifest.
        guard let manifestData = entries["manifest.json"] else {
            throw VoxError.manifestNotFound(url)
        }
        let manifest: VoxManifest
        do {
            manifest = try VoxManifest.decoder().decode(VoxManifest.self, from: manifestData)
        } catch {
            throw VoxError.invalidJSON(url, underlying: error)
        }

        // Step 2: Collect reference audio (entries under "reference/").
        var referenceAudio: [String: Data] = [:]
        for (path, data) in entries {
            if path.hasPrefix("reference/") {
                let filename = String(path.dropFirst("reference/".count))
                if !filename.isEmpty && !filename.contains("/") {
                    referenceAudio[filename] = data
                }
            }
        }

        // Step 3: Collect embeddings (entries under "embeddings/").
        var embeddings: [String: Data] = [:]
        for (path, data) in entries {
            if path.hasPrefix("embeddings/") {
                let relativePath = String(path.dropFirst("embeddings/".count))
                if !relativePath.isEmpty {
                    embeddings[relativePath] = data
                }
            }
        }

        let parsed = VoxFile(
            manifest: manifest,
            referenceAudio: referenceAudio,
            embeddings: embeddings
        )

        // Silently upgrade to current format version.
        return VoxMigrator.migrate(parsed)
    }
}
