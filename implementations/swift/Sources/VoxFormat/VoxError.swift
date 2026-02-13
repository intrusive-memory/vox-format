import Foundation

/// Errors that can occur when reading, writing, or validating VOX files.
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
        }
    }
}
