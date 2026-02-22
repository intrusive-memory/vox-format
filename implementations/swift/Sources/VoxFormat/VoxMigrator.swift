import Foundation

/// Silently upgrades VoxManifest instances from older format versions to the current version.
///
/// `VoxMigrator` is called automatically by ``VoxFile/init(contentsOf:)`` after parsing an archive.
/// It infers missing `embeddingEntries` from the `extensions` section and actual binary
/// files present in the archive, then bumps the version to ``VoxFormat/currentVersion``.
///
/// Migration is non-destructive and never throws — it does the best it can with available data.
internal struct VoxMigrator {

    /// Upgrades a VoxManifest to the current format version.
    ///
    /// - Parameters:
    ///   - manifest: The manifest as read from the archive.
    ///   - embeddingKeys: The set of relative paths under `embeddings/` that have binary data.
    /// - Returns: An upgraded manifest with current version and inferred embedding entries.
    static func migrateManifest(
        _ manifest: VoxManifest,
        embeddingKeys: Set<String>
    ) -> VoxManifest {
        var result = manifest

        // If embeddingEntries already populated, just bump version
        if result.embeddingEntries != nil && !(result.embeddingEntries?.isEmpty ?? true) {
            result.voxVersion = VoxFormat.currentVersion
            return result
        }

        // No embedding binaries in archive — nothing to infer
        guard !embeddingKeys.isEmpty else {
            result.voxVersion = VoxFormat.currentVersion
            return result
        }

        // Infer embeddingEntries from extensions + binary paths
        let extensionHints = extractExtensionHints(from: result.extensions)
        var entries: [String: VoxManifest.EmbeddingEntry] = [:]

        for relativePath in embeddingKeys {
            let fullPath = "embeddings/\(relativePath)"

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

        result.embeddingEntries = entries.isEmpty ? nil : entries
        result.voxVersion = VoxFormat.currentVersion

        return result
    }

    // MARK: - Extension Scanning

    private struct ExtensionHint {
        let key: String
        let engine: String?
        let model: String?
        let filePath: String
    }

    private static func extractExtensionHints(from extensions: [String: AnyCodable]?) -> [ExtensionHint] {
        guard let extensions else { return [] }
        var hints: [ExtensionHint] = []

        for (namespace, value) in extensions {
            guard let dict = value.value as? [String: Any] else { continue }

            for (innerKey, innerValue) in dict {
                guard let stringValue = innerValue as? String else { continue }
                if stringValue.hasPrefix("embeddings/") || innerKey == "clone_prompt" || innerKey == "embedding_file" {
                    let model = dict["model"] as? String
                    hints.append(ExtensionHint(
                        key: "\(namespace)-\(innerKey)",
                        engine: namespace,
                        model: model,
                        filePath: stringValue
                    ))
                }
            }
        }

        return hints
    }

    // MARK: - Path Derivation Helpers

    private static func deriveKey(from relativePath: String) -> String {
        let components = relativePath.split(separator: "/").map(String.init)
        let dirs = components.dropLast()
        if dirs.isEmpty {
            return (relativePath as NSString).deletingPathExtension
        }
        return dirs.joined(separator: "-")
    }

    private static func deriveModelName(from relativePath: String) -> String {
        deriveKey(from: relativePath)
    }

    private static func deriveEngine(from relativePath: String) -> String? {
        let components = relativePath.split(separator: "/")
        guard components.count > 1 else { return nil }
        return String(components[0])
    }

    private static func deriveFormat(from relativePath: String) -> String? {
        let ext = (relativePath as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }
}
