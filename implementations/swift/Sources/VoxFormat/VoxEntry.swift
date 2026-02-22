import Foundation

/// A single entry within a `.vox` archive, carrying its binary data and metadata.
///
/// `VoxEntry` represents one file inside the container — reference audio, embeddings,
/// or any other bundled asset. Each entry knows its archive path, MIME type, and
/// optional metadata relevant to manifest auto-management.
public final class VoxEntry: @unchecked Sendable {
    /// Archive-relative path (e.g., `"reference/sample.wav"`, `"embeddings/qwen3-tts/0.6b/clone-prompt.bin"`).
    public let path: String

    /// The raw binary data for this entry.
    public let data: Data

    /// MIME type for the entry (e.g., `"audio/wav"`, `"application/octet-stream"`).
    public let mimeType: String

    /// Entry-specific metadata used for manifest auto-management.
    ///
    /// For reference audio entries: `transcript`, `language`, `duration_seconds`, `context`.
    /// For embedding entries: `model` (required), `engine`, `format`, `description`, `key`.
    public let metadata: [String: Any]

    /// Creates a new `VoxEntry`.
    ///
    /// - Parameters:
    ///   - path: Archive-relative path for this entry.
    ///   - data: The binary data.
    ///   - mimeType: MIME type string. If not provided, inferred from the file extension.
    ///   - metadata: Optional metadata dictionary.
    public init(path: String, data: Data, mimeType: String? = nil, metadata: [String: Any]? = nil) {
        self.path = path
        self.data = data
        self.mimeType = mimeType ?? VoxMIME.mimeType(forPath: path)
        self.metadata = metadata ?? [:]
    }
}

/// Utilities for resolving MIME types from file extensions.
public enum VoxMIME {
    /// Returns the MIME type for a given file extension.
    ///
    /// Supported mappings:
    /// - `.wav` → `audio/wav`
    /// - `.flac` → `audio/flac`
    /// - `.mp3` → `audio/mpeg`
    /// - `.m4a` → `audio/mp4`
    /// - `.ogg` → `audio/ogg`
    /// - `.bin` → `application/octet-stream`
    /// - `.safetensors` → `application/x-safetensors`
    /// - `.onnx` → `application/x-onnx`
    /// - `.json` → `application/json`
    /// - Unknown → `application/octet-stream`
    public static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "wav":
            return "audio/wav"
        case "flac":
            return "audio/flac"
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "ogg":
            return "audio/ogg"
        case "bin":
            return "application/octet-stream"
        case "safetensors":
            return "application/x-safetensors"
        case "onnx":
            return "application/x-onnx"
        case "json":
            return "application/json"
        default:
            return "application/octet-stream"
        }
    }

    /// Returns the MIME type for a file path by extracting its extension.
    public static func mimeType(forPath path: String) -> String {
        let ext = (path as NSString).pathExtension
        return mimeType(forExtension: ext)
    }
}
