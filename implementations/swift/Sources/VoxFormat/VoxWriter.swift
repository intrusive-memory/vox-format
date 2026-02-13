import Foundation
import ZIPFoundation

/// Creates `.vox` voice identity archives from ``VoxFile`` instances.
///
/// `VoxWriter` takes a ``VoxFile`` and produces a valid `.vox` ZIP archive containing
/// the manifest JSON at the archive root, reference audio files in the `reference/`
/// directory, and engine-specific data in the `embeddings/` directory. The output
/// archive is verified to have correct ZIP magic bytes after creation.
///
/// ```swift
/// let manifest = VoxManifest(
///     voxVersion: "0.1.0",
///     id: UUID().uuidString.lowercased(),
///     created: Date(),
///     voice: VoxManifest.Voice(name: "Voice", description: "A warm narrator voice.")
/// )
/// let writer = VoxWriter()
/// try writer.write(VoxFile(manifest: manifest), to: URL(fileURLWithPath: "output.vox"))
/// ```
public final class VoxWriter {

    /// Creates a new `VoxWriter` instance.
    public init() {}

    /// Writes a ``VoxFile`` to a `.vox` ZIP archive at the specified URL.
    ///
    /// The method performs three steps:
    /// 1. Encodes the manifest to pretty-printed, sorted-key JSON.
    /// 2. Creates a ZIP archive with the manifest, reference audio, and embeddings.
    /// 3. Verifies the output file has correct ZIP magic bytes (`PK\x03\x04`).
    ///
    /// If a file already exists at the destination URL, it is overwritten.
    ///
    /// - Parameters:
    ///   - voxFile: The voice identity data to write, including manifest and file references.
    ///   - url: The destination file URL for the `.vox` archive.
    /// - Throws: ``VoxError/writeFailed(_:underlying:)`` if the archive cannot be created.
    /// - Throws: ``VoxError/ioError(_:underlying:)`` if file operations fail.
    ///
    /// ```swift
    /// let writer = VoxWriter()
    /// try writer.write(voxFile, to: URL(fileURLWithPath: "output.vox"))
    /// ```
    public func write(_ voxFile: VoxFile, to url: URL) throws {
        // Step 1: Encode manifest to JSON
        let manifestData = try encodeManifest(voxFile.manifest)

        // Step 2: Create the ZIP archive
        try createArchive(
            at: url,
            manifestData: manifestData,
            referenceAudioURLs: voxFile.referenceAudioURLs,
            extensionsDirectory: voxFile.extensionsDirectory
        )

        // Step 3: Verify ZIP magic bytes
        try verifyZipMagicBytes(at: url)
    }

    // MARK: - Manifest Encoding (VOX-042)

    /// Encodes a ``VoxManifest`` to pretty-printed JSON data.
    ///
    /// Uses the standard VOX encoder with sorted keys and pretty printing.
    ///
    /// - Parameter manifest: The manifest to encode.
    /// - Returns: UTF-8 encoded JSON data.
    /// - Throws: An encoding error if the manifest cannot be serialized.
    internal func encodeManifest(_ manifest: VoxManifest) throws -> Data {
        let encoder = VoxManifest.encoder()
        do {
            return try encoder.encode(manifest)
        } catch {
            throw VoxError.ioError(
                "Failed to encode manifest to JSON",
                underlying: error
            )
        }
    }

    // MARK: - Archive Creation (VOX-043)

    /// Creates a ZIP archive from manifest data and associated files.
    ///
    /// - Parameters:
    ///   - url: The destination file URL.
    ///   - manifestData: The encoded manifest JSON data.
    ///   - referenceAudioURLs: URLs to reference audio files to include.
    ///   - extensionsDirectory: Optional directory containing engine-specific data.
    internal func createArchive(
        at url: URL,
        manifestData: Data,
        referenceAudioURLs: [URL],
        extensionsDirectory: URL?
    ) throws {
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let archive = Archive(url: url, accessMode: .create) else {
            throw VoxError.writeFailed(url)
        }

        // Add manifest.json at archive root
        do {
            try archive.addEntry(
                with: "manifest.json",
                type: .file,
                uncompressedSize: Int64(manifestData.count),
                provider: { position, size in
                    let start = Int(position)
                    let end = min(start + size, manifestData.count)
                    return manifestData[start..<end]
                }
            )
        } catch {
            throw VoxError.writeFailed(url, underlying: error)
        }

        // Add reference audio files if they exist
        if !referenceAudioURLs.isEmpty {
            for audioURL in referenceAudioURLs {
                let fileName = audioURL.lastPathComponent
                let archivePath = "reference/\(fileName)"

                do {
                    try archive.addEntry(
                        with: archivePath,
                        fileURL: audioURL
                    )
                } catch {
                    throw VoxError.writeFailed(url, underlying: error)
                }
            }
        }

        // Add embeddings directory if present
        if let extensionsDir = extensionsDirectory {
            try addDirectoryContents(
                from: extensionsDir,
                toArchive: archive,
                withPrefix: "embeddings",
                archiveURL: url
            )
        }
    }

    /// Recursively adds the contents of a directory to a ZIP archive.
    ///
    /// - Parameters:
    ///   - directory: The source directory.
    ///   - archive: The ZIP archive to add files to.
    ///   - prefix: The path prefix within the archive.
    ///   - archiveURL: The archive URL (for error messages).
    private func addDirectoryContents(
        from directory: URL,
        toArchive archive: Archive,
        withPrefix prefix: String,
        archiveURL: URL
    ) throws {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(
                forKeys: [.isRegularFileKey]
            )
            guard resourceValues.isRegularFile == true else { continue }

            // Compute relative path from the source directory
            let relativePath = fileURL.path.replacingOccurrences(
                of: directory.path + "/",
                with: ""
            )
            let archivePath = "\(prefix)/\(relativePath)"

            do {
                try archive.addEntry(
                    with: archivePath,
                    fileURL: fileURL
                )
            } catch {
                throw VoxError.writeFailed(archiveURL, underlying: error)
            }
        }
    }

    // MARK: - Verification

    /// Verifies that a file begins with ZIP magic bytes (PK\x03\x04).
    ///
    /// - Parameter url: The file to verify.
    /// - Throws: ``VoxError/writeFailed(_:underlying:)`` if the magic bytes don't match.
    internal func verifyZipMagicBytes(at url: URL) throws {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw VoxError.writeFailed(url, underlying: error)
        }

        defer { handle.closeFile() }

        let magicData = handle.readData(ofLength: 4)
        let expectedMagic: [UInt8] = [0x50, 0x4B, 0x03, 0x04] // PK\x03\x04

        guard magicData.count == 4,
              Array(magicData) == expectedMagic else {
            throw VoxError.writeFailed(
                url,
                underlying: NSError(
                    domain: "VoxFormat",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Output file does not have ZIP magic bytes (PK\\x03\\x04)"
                    ]
                )
            )
        }
    }
}
