import Foundation

/// Errors that can occur when reading, writing, or validating VOX files.
///
/// `VoxError` covers all failure modes in the VoxFormat library: archive extraction
/// errors, manifest parsing failures, validation violations, and I/O problems. Each
/// case provides a descriptive ``errorDescription`` suitable for user-facing messages.
/// Validation errors may be collected into ``validationErrors(_:)`` when using
/// ``VoxValidator`` in permissive mode.
public enum VoxError: Error, LocalizedError {
    /// The file is not a valid ZIP archive.
    case invalidZipFile(URL, underlying: Error? = nil)

    /// The manifest.json file is missing from the archive.
    case manifestNotFound(URL)

    /// The manifest.json file contains invalid JSON.
    case invalidJSON(URL, underlying: Error)

    /// A referenced file is missing from the archive.
    case missingReferencedFile(path: String, archive: URL)

    /// An I/O error occurred during file operations.
    case ioError(String, underlying: Error? = nil)

    /// The write operation failed.
    case writeFailed(URL, underlying: Error? = nil)

    /// A feature is not yet implemented.
    case notImplemented(String)

    /// A required field is empty or missing.
    case emptyRequiredField(field: String)

    /// The UUID is not in valid v4 format.
    case invalidUUID(String)

    /// The timestamp is not in valid ISO 8601 format.
    case invalidTimestamp(String)

    /// A voice description is too short (minimum 10 characters).
    case descriptionTooShort(field: String, length: Int, minimum: Int)

    /// An age range has invalid values (min must be less than max).
    case invalidAgeRange(min: Int, max: Int)

    /// A gender value is not one of the allowed enum values.
    case invalidGender(String)

    /// A reference audio entry has an empty file path.
    case emptyReferenceAudioPath(index: Int)

    /// An embedding entry in the manifest is invalid.
    case invalidEmbeddingEntry(key: String, reason: String)

    /// A declared file is missing from the archive bundle.
    case missingBundledFile(declaredPath: String, section: String)

    /// Multiple validation errors occurred.
    case validationErrors([VoxError])

    /// An archive path is invalid (empty or reserved).
    case invalidPath(String, reason: String)

    /// A required metadata key is missing for an entry.
    case missingRequiredMetadata(path: String, key: String)

    public var errorDescription: String? {
        switch self {
        case .invalidZipFile(let url, let underlying):
            var msg = "Not a valid ZIP archive: \(url.lastPathComponent)"
            if let underlying {
                msg += " (\(underlying.localizedDescription))"
            }
            return msg
        case .manifestNotFound(let url):
            return "manifest.json not found in archive: \(url.lastPathComponent)"
        case .invalidJSON(let url, let underlying):
            return "Invalid JSON in manifest.json from \(url.lastPathComponent): \(underlying.localizedDescription)"
        case .missingReferencedFile(let path, let archive):
            return "Referenced file '\(path)' not found in archive: \(archive.lastPathComponent)"
        case .ioError(let message, let underlying):
            var msg = "I/O error: \(message)"
            if let underlying {
                msg += " (\(underlying.localizedDescription))"
            }
            return msg
        case .writeFailed(let url, let underlying):
            var msg = "Failed to write VOX file: \(url.lastPathComponent)"
            if let underlying {
                msg += " (\(underlying.localizedDescription))"
            }
            return msg
        case .notImplemented(let feature):
            return "Not implemented: \(feature)"
        case .emptyRequiredField(let field):
            return "Required field '\(field)' is empty or missing"
        case .invalidUUID(let value):
            return "Invalid UUID v4 format: '\(value)'"
        case .invalidTimestamp(let value):
            return "Invalid ISO 8601 timestamp: '\(value)'"
        case .descriptionTooShort(let field, let length, let minimum):
            return "Field '\(field)' is too short (\(length) characters, minimum \(minimum))"
        case .invalidAgeRange(let min, let max):
            return "Invalid age range: minimum (\(min)) must be less than maximum (\(max))"
        case .invalidGender(let value):
            return "Invalid gender value '\(value)'. Must be one of: male, female, nonbinary, neutral"
        case .emptyReferenceAudioPath(let index):
            return "Reference audio entry at index \(index) has an empty file path"
        case .invalidEmbeddingEntry(let key, let reason):
            return "Invalid embedding entry '\(key)': \(reason)"
        case .missingBundledFile(let declaredPath, let section):
            return "Declared file '\(declaredPath)' is missing from the '\(section)' section of the archive"
        case .validationErrors(let errors):
            let descriptions = errors.compactMap { $0.errorDescription }
            return "Validation failed with \(errors.count) error(s):\n" + descriptions.joined(separator: "\n")
        case .invalidPath(let path, let reason):
            return "Invalid path '\(path)': \(reason)"
        case .missingRequiredMetadata(let path, let key):
            return "Missing required metadata '\(key)' for entry at '\(path)'"
        }
    }
}
