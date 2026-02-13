import Foundation
import ZIPFoundation

/// Reads and parses `.vox` voice identity archives.
///
/// `VoxReader` extracts a `.vox` ZIP archive to a temporary directory, parses
/// the `manifest.json`, discovers reference audio files, and returns a fully
/// populated ``VoxFile``. The extraction process handles ZIP decompression via
/// ZIPFoundation, validates the archive structure, and resolves file references
/// declared in the manifest.
///
/// ```swift
/// let reader = VoxReader()
/// let voxFile = try reader.read(from: URL(fileURLWithPath: "voice.vox"))
/// print(voxFile.manifest.voice.name)
/// print(voxFile.manifest.voice.description)
/// print("Audio files: \(voxFile.referenceAudioURLs.count)")
/// ```
public final class VoxReader {

    /// Creates a new `VoxReader` instance.
    public init() {}

    /// Reads a `.vox` archive and returns a fully populated ``VoxFile``.
    ///
    /// The method performs four steps:
    /// 1. Extracts the ZIP archive to a temporary directory.
    /// 2. Parses `manifest.json` into a ``VoxManifest``.
    /// 3. Discovers reference audio files in the `reference/` directory.
    /// 4. Locates the `embeddings/` directory if present.
    ///
    /// On failure, the temporary directory is cleaned up before the error is thrown.
    ///
    /// - Parameter url: The file URL of the `.vox` archive to read.
    /// - Returns: A ``VoxFile`` containing the parsed manifest and file references.
    /// - Throws: ``VoxError/invalidZipFile(_:underlying:)`` if the file is not a valid ZIP archive.
    /// - Throws: ``VoxError/manifestNotFound(_:)`` if `manifest.json` is missing from the archive.
    /// - Throws: ``VoxError/invalidJSON(_:underlying:)`` if `manifest.json` cannot be decoded.
    ///
    /// ```swift
    /// let reader = VoxReader()
    /// do {
    ///     let voxFile = try reader.read(from: fileURL)
    ///     print(voxFile.manifest.voice.name)
    /// } catch {
    ///     print("Failed to read: \(error.localizedDescription)")
    /// }
    /// ```
    public func read(from url: URL) throws -> VoxFile {
        // Step 1: Extract the ZIP archive to a temporary directory
        let extractedDir = try extractArchive(at: url)

        do {
            // Step 2: Parse the manifest
            let manifest = try parseManifest(in: extractedDir, archiveURL: url)

            // Step 3: Discover reference audio files
            let audioURLs = enumerateReferenceAudio(
                in: extractedDir,
                manifest: manifest
            )

            // Step 4: Locate embeddings directory if present
            let embeddingsDir = locateEmbeddingsDirectory(in: extractedDir)

            return VoxFile(
                manifest: manifest,
                referenceAudioURLs: audioURLs,
                extensionsDirectory: embeddingsDir
            )
        } catch {
            // Clean up temp directory on error
            try? FileManager.default.removeItem(at: extractedDir)
            throw error
        }
    }

    // MARK: - ZIP Extraction (VOX-036)

    /// Extracts a `.vox` ZIP archive to a temporary directory.
    ///
    /// - Parameter url: The file URL of the `.vox` archive.
    /// - Returns: The URL of the temporary directory containing extracted files.
    /// - Throws: ``VoxError/invalidZipFile(_:underlying:)`` if the archive cannot be opened.
    internal func extractArchive(at url: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
        } catch {
            throw VoxError.ioError(
                "Failed to create temporary directory",
                underlying: error
            )
        }

        do {
            guard let archive = Archive(url: url, accessMode: .read) else {
                // Clean up before throwing
                try? FileManager.default.removeItem(at: tempDir)
                throw VoxError.invalidZipFile(url)
            }

            for entry in archive {
                let destinationURL = tempDir.appendingPathComponent(entry.path)
                _ = try archive.extract(entry, to: destinationURL)
            }
        } catch let error as VoxError {
            // VoxError already created, just rethrow after cleanup
            try? FileManager.default.removeItem(at: tempDir)
            throw error
        } catch {
            // Wrap other errors as invalidZipFile
            try? FileManager.default.removeItem(at: tempDir)
            throw VoxError.invalidZipFile(url, underlying: error)
        }

        return tempDir
    }

    // MARK: - Manifest Parsing (VOX-037)

    /// Parses `manifest.json` from an extracted archive directory.
    ///
    /// - Parameters:
    ///   - directory: The extracted archive directory.
    ///   - archiveURL: The original archive URL (for error messages).
    /// - Returns: The decoded ``VoxManifest``.
    /// - Throws: ``VoxError/manifestNotFound(_:)`` if the file doesn't exist.
    /// - Throws: ``VoxError/invalidJSON(_:underlying:)`` if decoding fails.
    internal func parseManifest(
        in directory: URL,
        archiveURL: URL
    ) throws -> VoxManifest {
        let manifestURL = directory.appendingPathComponent("manifest.json")

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw VoxError.manifestNotFound(archiveURL)
        }

        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw VoxError.ioError(
                "Failed to read manifest.json",
                underlying: error
            )
        }

        do {
            let decoder = VoxManifest.decoder()
            return try decoder.decode(VoxManifest.self, from: data)
        } catch {
            throw VoxError.invalidJSON(archiveURL, underlying: error)
        }
    }

    // MARK: - Reference Audio Enumeration (VOX-038)

    /// Discovers reference audio files in the extracted archive.
    ///
    /// If the manifest specifies `reference_audio` entries, this method resolves
    /// their file paths against the extracted directory. If the `reference/` directory
    /// doesn't exist, an empty array is returned.
    ///
    /// - Parameters:
    ///   - directory: The extracted archive directory.
    ///   - manifest: The parsed manifest to match against.
    /// - Returns: An array of URLs to discovered audio files.
    internal func enumerateReferenceAudio(
        in directory: URL,
        manifest: VoxManifest
    ) -> [URL] {
        guard let referenceAudioEntries = manifest.referenceAudio,
              !referenceAudioEntries.isEmpty else {
            return []
        }

        let referenceDir = directory.appendingPathComponent("reference")

        guard FileManager.default.fileExists(atPath: referenceDir.path) else {
            // No reference directory, but manifest references audio --
            // return what we can resolve from manifest paths
            return referenceAudioEntries.compactMap { entry in
                let fileURL = directory.appendingPathComponent(entry.file)
                return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
            }
        }

        // Match files against manifest reference_audio paths
        return referenceAudioEntries.compactMap { entry in
            let fileURL = directory.appendingPathComponent(entry.file)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
            return nil
        }
    }

    // MARK: - Embeddings Directory

    /// Locates the embeddings directory in the extracted archive, if present.
    ///
    /// - Parameter directory: The extracted archive directory.
    /// - Returns: The URL of the embeddings directory, or `nil` if not present.
    internal func locateEmbeddingsDirectory(in directory: URL) -> URL? {
        let embeddingsDir = directory.appendingPathComponent("embeddings")
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(
            atPath: embeddingsDir.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue {
            return embeddingsDir
        }
        return nil
    }
}
