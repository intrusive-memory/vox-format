import Foundation
import ZIPFoundation

/// Creates `.vox` voice identity archives from ``VoxFile`` instances.
///
/// `VoxWriter` takes a ``VoxFile`` and produces a valid `.vox` ZIP archive containing
/// the manifest JSON at the archive root, reference audio in `reference/`, and
/// engine-specific embeddings in `embeddings/`. All data is written directly from
/// memory — no temporary files are needed.
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
    /// If a file already exists at the destination URL, it is overwritten.
    ///
    /// - Parameters:
    ///   - voxFile: The voice identity data to write.
    ///   - url: The destination file URL for the `.vox` archive.
    /// - Throws: ``VoxError/writeFailed(_:underlying:)`` if the archive cannot be created.
    public func write(_ voxFile: VoxFile, to url: URL) throws {
        // Always stamp the current format version on write.
        var manifest = voxFile.manifest
        manifest.voxVersion = VoxFormat.currentVersion
        let manifestData = try encodeManifest(manifest)

        // Remove existing file if present.
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let archive = Archive(url: url, accessMode: .create) else {
            throw VoxError.writeFailed(url)
        }

        // Write manifest.json at archive root.
        try addDataEntry(to: archive, path: "manifest.json", data: manifestData, archiveURL: url)

        // Write reference audio files.
        for (filename, data) in voxFile.referenceAudio {
            try addDataEntry(to: archive, path: "reference/\(filename)", data: data, archiveURL: url)
        }

        // Write embeddings.
        for (relativePath, data) in voxFile.embeddings {
            try addDataEntry(to: archive, path: "embeddings/\(relativePath)", data: data, archiveURL: url)
        }

        // Verify ZIP magic bytes.
        try verifyZipMagicBytes(at: url)
    }

    // MARK: - Manifest Encoding

    /// Encodes a ``VoxManifest`` to pretty-printed JSON data.
    internal func encodeManifest(_ manifest: VoxManifest) throws -> Data {
        do {
            return try VoxManifest.encoder().encode(manifest)
        } catch {
            throw VoxError.ioError("Failed to encode manifest to JSON", underlying: error)
        }
    }

    // MARK: - Archive Helpers

    /// Adds a `Data` blob as a file entry in the archive.
    private func addDataEntry(
        to archive: Archive,
        path: String,
        data: Data,
        archiveURL: URL
    ) throws {
        do {
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                provider: { position, size in
                    let start = Int(position)
                    let end = min(start + size, data.count)
                    return data[start..<end]
                }
            )
        } catch {
            throw VoxError.writeFailed(archiveURL, underlying: error)
        }
    }

    // MARK: - Verification

    /// Verifies that a file begins with ZIP magic bytes (PK\x03\x04).
    internal func verifyZipMagicBytes(at url: URL) throws {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw VoxError.writeFailed(url, underlying: error)
        }

        defer { handle.closeFile() }

        let magicData = handle.readData(ofLength: 4)
        let expectedMagic: [UInt8] = [0x50, 0x4B, 0x03, 0x04]

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
