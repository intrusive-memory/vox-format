import Foundation

/// Silently upgrades `VoxFile` instances from older format versions to the current version.
///
/// `VoxMigrator` is called automatically by ``VoxReader`` after parsing an archive.
/// It infers missing `embeddingEntries` from the `extensions` section and actual binary
/// files present in the archive, then bumps the version to ``VoxFormat/currentVersion``.
///
/// Migration is non-destructive and never throws — it does the best it can with available data.
public struct VoxMigrator {

    /// Upgrades a VoxFile to the current format version.
    ///
    /// - If `embeddingEntries` is already populated, only bumps the version if needed.
    /// - If `embeddingEntries` is nil and embedding binaries exist, infers entries from
    ///   `extensions` metadata and archive paths.
    ///
    /// - Parameter voxFile: The VoxFile as read from the archive.
    /// - Returns: An upgraded VoxFile with current version and inferred embedding entries.
    public static func migrate(_ voxFile: VoxFile) -> VoxFile {
        var manifest = voxFile.manifest

        // If embeddingEntries already populated, just bump version
        if manifest.embeddingEntries != nil && !(manifest.embeddingEntries?.isEmpty ?? true) {
            manifest.voxVersion = VoxFormat.currentVersion
            return VoxFile(
                manifest: manifest,
                referenceAudio: voxFile.referenceAudio,
                embeddings: voxFile.embeddings
            )
        }

        // No embedding binaries in archive — nothing to infer
        guard !voxFile.embeddings.isEmpty else {
            manifest.voxVersion = VoxFormat.currentVersion
            return VoxFile(
                manifest: manifest,
                referenceAudio: voxFile.referenceAudio,
                embeddings: voxFile.embeddings
            )
        }

        // Infer embeddingEntries from extensions + binary paths
        let extensionHints = extractExtensionHints(from: manifest.extensions)
        var entries: [String: VoxManifest.EmbeddingEntry] = [:]

        for relativePath in voxFile.embeddings.keys {
            let fullPath = "embeddings/\(relativePath)"

            // Try to match to an extension hint
            if let hint = extensionHints.first(where: { $0.filePath == fullPath || $0.filePath == relativePath }) {
                let key = hint.key
                entries[key] = VoxManifest.EmbeddingEntry(
                    model: hint.model ?? deriveModelName(from: relativePath),
                    engine: hint.engine,
                    file: fullPath,
                    format: deriveFormat(from: relativePath),
                    description: "Migrated from v0.1.0 extensions"
                )
            } else {
                // Orphan binary — derive key and model from path
                let key = deriveKey(from: relativePath)
                entries[key] = VoxManifest.EmbeddingEntry(
                    model: deriveModelName(from: relativePath),
                    engine: deriveEngine(from: relativePath),
                    file: fullPath,
                    format: deriveFormat(from: relativePath),
                    description: "Inferred from archive binary (v0.1.0 migration)"
                )
            }
        }

        manifest.embeddingEntries = entries.isEmpty ? nil : entries
        manifest.voxVersion = VoxFormat.currentVersion

        return VoxFile(
            manifest: manifest,
            referenceAudio: voxFile.referenceAudio,
            embeddings: voxFile.embeddings
        )
    }

    // MARK: - Extension Scanning

    private struct ExtensionHint {
        let key: String
        let engine: String?
        let model: String?
        let filePath: String
    }

    /// Scans the extensions dictionary for engine namespaces that reference embedding files.
    private static func extractExtensionHints(from extensions: [String: AnyCodable]?) -> [ExtensionHint] {
        guard let extensions else { return [] }
        var hints: [ExtensionHint] = []

        for (namespace, value) in extensions {
            guard let dict = value.value as? [String: Any] else { continue }

            // Look for keys that reference embedding files
            for (innerKey, innerValue) in dict {
                guard let stringValue = innerValue as? String else { continue }
                if stringValue.hasPrefix("embeddings/") || innerKey == "clone_prompt" || innerKey == "embedding_file" {
                    let filePath = stringValue.hasPrefix("embeddings/") ? stringValue : stringValue
                    let model = dict["model"] as? String
                    hints.append(ExtensionHint(
                        key: "\(namespace)-\(innerKey)",
                        engine: namespace,
                        model: model,
                        filePath: filePath
                    ))
                }
            }
        }

        return hints
    }

    // MARK: - Path Derivation Helpers

    /// Derives a human-readable key from a relative embedding path.
    /// e.g., `"qwen3-tts/0.6b/clone-prompt.bin"` → `"qwen3-tts-0.6b"`
    private static func deriveKey(from relativePath: String) -> String {
        let components = relativePath.split(separator: "/").map(String.init)
        // Drop the filename, join directory components
        let dirs = components.dropLast()
        if dirs.isEmpty {
            // Single file like "clone-prompt.bin"
            let name = (relativePath as NSString).deletingPathExtension
            return name
        }
        return dirs.joined(separator: "-")
    }

    /// Derives a model name from the path.
    /// e.g., `"qwen3-tts/0.6b/clone-prompt.bin"` → `"qwen3-tts-0.6b"`
    private static func deriveModelName(from relativePath: String) -> String {
        deriveKey(from: relativePath)
    }

    /// Derives the engine namespace from the first directory component.
    /// e.g., `"qwen3-tts/0.6b/clone-prompt.bin"` → `"qwen3-tts"`
    private static func deriveEngine(from relativePath: String) -> String? {
        let components = relativePath.split(separator: "/")
        guard components.count > 1 else { return nil }
        return String(components[0])
    }

    /// Derives the binary format from the file extension.
    private static func deriveFormat(from relativePath: String) -> String? {
        let ext = (relativePath as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }
}
