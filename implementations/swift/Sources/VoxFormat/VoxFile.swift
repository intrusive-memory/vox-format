import Foundation
import ZIPFoundation

/// A mutable, in-memory container representing a `.vox` voice identity archive.
///
/// `VoxFile` is **the** API for working with VOX files. It manages entries (reference audio,
/// embeddings, and other assets), auto-updates the manifest when entries are added or removed,
/// and handles reading from and writing to `.vox` ZIP archives.
///
/// ```swift
/// // Create a new voice
/// let vox = VoxFile(name: "Narrator", description: "A warm, clear narrator voice.")
/// try vox.add(audioData, at: "reference/sample.wav", metadata: [
///     "transcript": "Hello world.",
///     "language": "en-US"
/// ])
/// try vox.write(to: URL(fileURLWithPath: "narrator.vox"))
///
/// // Open an existing voice
/// let existing = try VoxFile(contentsOf: URL(fileURLWithPath: "voice.vox"))
/// print(existing.manifest.voice.name)
/// if let sample = existing["reference/sample.wav"] {
///     print("Audio: \(sample.data.count) bytes")
/// }
/// ```
public final class VoxFile {

    /// The parsed manifest containing all voice identity metadata.
    public var manifest: VoxManifest

    /// Internal storage of entries keyed by archive path.
    private var storage: [String: VoxEntry] = [:]

    // MARK: - Initializers

    /// Creates a new, empty VoxFile with the given voice name and description.
    ///
    /// Generates a fresh UUID and timestamp automatically.
    ///
    /// - Parameters:
    ///   - name: Display name for the voice.
    ///   - description: Natural language description (minimum 10 characters).
    public init(name: String, description: String) {
        self.manifest = VoxManifest(
            voxVersion: VoxFormat.currentVersion,
            id: UUID().uuidString.lowercased(),
            created: Date(),
            voice: VoxManifest.Voice(name: name, description: description)
        )
    }

    /// Creates a VoxFile from an existing manifest.
    ///
    /// - Parameter manifest: The voice identity manifest.
    public init(manifest: VoxManifest) {
        self.manifest = manifest
    }

    /// Opens a `.vox` archive from disk and reads all entries into memory.
    ///
    /// Silently migrates older format versions to the current version.
    ///
    /// - Parameter url: The file URL of the `.vox` archive to read.
    /// - Throws: ``VoxError/invalidZipFile(_:underlying:)`` if the file is not a valid ZIP archive.
    /// - Throws: ``VoxError/manifestNotFound(_:)`` if `manifest.json` is missing.
    /// - Throws: ``VoxError/invalidJSON(_:underlying:)`` if `manifest.json` cannot be decoded.
    public init(contentsOf url: URL) throws {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw VoxError.invalidZipFile(url)
        }

        // Collect all entries into memory.
        var rawEntries: [String: Data] = [:]
        for entry in archive where entry.type == .file {
            var entryData = Data()
            _ = try archive.extract(entry) { chunk in
                entryData.append(chunk)
            }
            rawEntries[entry.path] = entryData
        }

        // Parse manifest.
        guard let manifestData = rawEntries["manifest.json"] else {
            throw VoxError.manifestNotFound(url)
        }
        let parsedManifest: VoxManifest
        do {
            parsedManifest = try VoxManifest.decoder().decode(VoxManifest.self, from: manifestData)
        } catch {
            throw VoxError.invalidJSON(url, underlying: error)
        }

        // Build legacy-format dicts for migration.
        var referenceAudio: [String: Data] = [:]
        var embeddings: [String: Data] = [:]
        for (path, data) in rawEntries {
            if path == "manifest.json" { continue }
            if path.hasPrefix("reference/") {
                let filename = String(path.dropFirst("reference/".count))
                if !filename.isEmpty && !filename.contains("/") {
                    referenceAudio[filename] = data
                }
            } else if path.hasPrefix("embeddings/") {
                let relativePath = String(path.dropFirst("embeddings/".count))
                if !relativePath.isEmpty {
                    embeddings[relativePath] = data
                }
            }
        }

        // Migrate using the legacy VoxMigrator.
        let migratedManifest = VoxMigrator.migrateManifest(
            parsedManifest,
            embeddingKeys: Set(embeddings.keys)
        )
        self.manifest = migratedManifest

        // Populate storage from raw entries (excluding manifest.json).
        for (path, data) in rawEntries where path != "manifest.json" {
            self.storage[path] = VoxEntry(path: path, data: data)
        }
    }

    // MARK: - Entry Management

    /// Adds data at the given archive path, auto-updating the manifest.
    ///
    /// - If the path starts with `reference/`, a ``VoxManifest/ReferenceAudio`` entry
    ///   is created/updated. Metadata keys: `transcript` (String), `language` (String),
    ///   `duration_seconds` (Double), `context` (String).
    /// - If the path starts with `embeddings/`, a ``VoxManifest/EmbeddingEntry`` is
    ///   created/updated. Metadata key `model` (String) is **required**.
    ///   Optional: `engine`, `format`, `description`, `key`.
    /// - Other paths are stored and round-tripped without manifest effect.
    ///
    /// Adding at an existing path replaces the entry.
    ///
    /// - Parameters:
    ///   - data: The binary data to store.
    ///   - path: Archive-relative path (e.g., `"reference/sample.wav"`).
    ///   - mimeType: Optional MIME type (inferred from extension if nil).
    ///   - metadata: Optional metadata dictionary for manifest auto-management.
    /// - Returns: The created ``VoxEntry``.
    /// - Throws: ``VoxError/invalidPath(_:reason:)`` for empty or reserved paths.
    /// - Throws: ``VoxError/missingRequiredMetadata(path:key:)`` for embedding entries without `model`.
    @discardableResult
    public func add(
        _ data: Data,
        at path: String,
        mimeType: String? = nil,
        metadata: [String: Any]? = nil
    ) throws -> VoxEntry {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw VoxError.invalidPath(path, reason: "path must not be empty")
        }
        guard trimmed != "manifest.json" else {
            throw VoxError.invalidPath(path, reason: "manifest.json is reserved")
        }

        let entry = VoxEntry(path: trimmed, data: data, mimeType: mimeType, metadata: metadata)

        // Replace semantics: remove old entry's manifest effect first.
        if storage[trimmed] != nil {
            removeManifestEntry(for: trimmed)
        }

        storage[trimmed] = entry
        addManifestEntry(for: entry)

        return entry
    }

    /// Removes the entry at the given path, auto-updating the manifest.
    ///
    /// - Parameter path: The archive-relative path to remove.
    /// - Returns: The removed ``VoxEntry``, or `nil` if not found.
    @discardableResult
    public func remove(at path: String) -> VoxEntry? {
        guard let entry = storage.removeValue(forKey: path) else { return nil }
        removeManifestEntry(for: path)
        return entry
    }

    /// Accesses the entry at the given archive path.
    public subscript(path: String) -> VoxEntry? {
        storage[path]
    }

    /// All entries in the container.
    public var entries: [VoxEntry] {
        Array(storage.values)
    }

    /// Returns entries whose paths start with the given prefix.
    ///
    /// - Parameter prefix: The path prefix to filter by (e.g., `"reference/"`, `"embeddings/"`).
    /// - Returns: Matching entries.
    public func entries(under prefix: String) -> [VoxEntry] {
        storage.values.filter { $0.path.hasPrefix(prefix) }
    }

    /// Whether the container has an entry at the given path.
    public func contains(path: String) -> Bool {
        storage[path] != nil
    }

    /// The number of entries (excluding manifest.json).
    public var entryCount: Int {
        storage.count
    }

    // MARK: - I/O

    /// Writes the VoxFile to a `.vox` ZIP archive at the specified URL.
    ///
    /// Always stamps the current format version on write. If a file already exists
    /// at the destination, it is overwritten.
    ///
    /// - Parameter url: The destination file URL.
    /// - Throws: ``VoxError/writeFailed(_:underlying:)`` if the archive cannot be created.
    public func write(to url: URL) throws {
        var writeManifest = manifest
        writeManifest.voxVersion = VoxFormat.currentVersion
        let manifestData: Data
        do {
            manifestData = try VoxManifest.encoder().encode(writeManifest)
        } catch {
            throw VoxError.ioError("Failed to encode manifest to JSON", underlying: error)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let archive = Archive(url: url, accessMode: .create) else {
            throw VoxError.writeFailed(url)
        }

        try addDataEntry(to: archive, path: "manifest.json", data: manifestData, archiveURL: url)

        for entry in storage.values {
            try addDataEntry(to: archive, path: entry.path, data: entry.data, archiveURL: url)
        }

        try verifyZipMagicBytes(at: url)
    }

    // MARK: - Readiness

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

        if let entries = manifest.embeddingEntries {
            for (key, entry) in entries {
                if storage[entry.file] == nil {
                    // Also check without embeddings/ prefix for backward compat
                    let altPath = entry.file.hasPrefix("embeddings/")
                        ? entry.file
                        : "embeddings/\(entry.file)"
                    if storage[altPath] == nil {
                        missingEmbeddings.append(key)
                    }
                }
            }
        }

        if let refAudioEntries = manifest.referenceAudio {
            for entry in refAudioEntries {
                if storage[entry.file] == nil {
                    let altPath = entry.file.hasPrefix("reference/")
                        ? entry.file
                        : "reference/\(entry.file)"
                    if storage[altPath] == nil {
                        missingEmbeddings.append("reference:\(entry.file)")
                    }
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

    // MARK: - Private Helpers

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

    private func verifyZipMagicBytes(at url: URL) throws {
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
