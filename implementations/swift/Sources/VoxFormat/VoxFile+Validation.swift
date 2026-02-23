import Foundation

/// A single validation finding for a VoxFile.
public struct VoxIssue: Sendable, CustomStringConvertible {
    /// Severity level of the issue.
    public enum Severity: Comparable, Sendable {
        case info
        case warning
        case error
    }

    /// The severity of this issue.
    public let severity: Severity

    /// Human-readable description of the issue.
    public let message: String

    /// The manifest field path related to this issue (e.g., `"voice.name"`), if applicable.
    public let field: String?

    public init(severity: Severity, message: String, field: String? = nil) {
        self.severity = severity
        self.message = message
        self.field = field
    }

    public var description: String {
        let prefix: String
        switch severity {
        case .info: prefix = "INFO"
        case .warning: prefix = "WARNING"
        case .error: prefix = "ERROR"
        }
        if let field {
            return "[\(prefix)] \(field): \(message)"
        }
        return "[\(prefix)] \(message)"
    }
}

// MARK: - Validation

extension VoxFile {

    /// The set of valid gender values per the VOX specification.
    private static let validGenders: Set<String> = ["male", "female", "nonbinary", "neutral"]

    /// Regular expression pattern for UUID v4 format.
    private static let uuidV4Pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

    /// The minimum length for the voice description field.
    private static let minimumDescriptionLength = 10

    /// The set of known provenance method values per the VOX specification.
    private static let knownMethods: Set<String> = ["designed", "synthesized", "cloned", "preset", "hybrid"]

    /// Validates this VoxFile against the VOX format specification.
    ///
    /// Returns an array of ``VoxIssue`` findings. An empty array means the file is valid.
    /// Issues with `.error` severity indicate specification violations.
    ///
    /// - Returns: An array of validation issues found.
    public func validate() -> [VoxIssue] {
        var issues: [VoxIssue] = []

        validateRequiredFields(&issues)
        validateOptionalFields(&issues)
        validateEmbeddingEntries(&issues)
        validateBundleCompleteness(&issues)
        validateProvenance(&issues)
        validateReferenceAudioModelTags(&issues)

        return issues
    }

    /// Convenience: `true` when `validate()` returns no `.error`-severity issues.
    public var isValid: Bool {
        !validate().contains { $0.severity == .error }
    }

    // MARK: - Required Fields

    private func validateRequiredFields(_ issues: inout [VoxIssue]) {
        if manifest.voxVersion.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(VoxIssue(
                severity: .error,
                message: "Required field is empty or missing",
                field: "vox_version"
            ))
        }

        if !Self.isValidUUIDv4(manifest.id) {
            issues.append(VoxIssue(
                severity: .error,
                message: "Invalid UUID v4 format: '\(manifest.id)'",
                field: "id"
            ))
        }

        let interval = manifest.created.timeIntervalSince1970
        if !interval.isFinite || interval.isNaN {
            issues.append(VoxIssue(
                severity: .error,
                message: "Invalid timestamp",
                field: "created"
            ))
        }

        if manifest.voice.name.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(VoxIssue(
                severity: .error,
                message: "Required field is empty or missing",
                field: "voice.name"
            ))
        }

        let descLength = manifest.voice.description.trimmingCharacters(in: .whitespaces).count
        if descLength == 0 {
            issues.append(VoxIssue(
                severity: .error,
                message: "Required field is empty or missing",
                field: "voice.description"
            ))
        } else if descLength < Self.minimumDescriptionLength {
            issues.append(VoxIssue(
                severity: .error,
                message: "Too short (\(descLength) characters, minimum \(Self.minimumDescriptionLength))",
                field: "voice.description"
            ))
        }
    }

    // MARK: - Optional Fields

    private func validateOptionalFields(_ issues: inout [VoxIssue]) {
        if let ageRange = manifest.voice.ageRange, ageRange.count == 2 {
            if ageRange[0] >= ageRange[1] {
                issues.append(VoxIssue(
                    severity: .error,
                    message: "Minimum (\(ageRange[0])) must be less than maximum (\(ageRange[1]))",
                    field: "voice.age_range"
                ))
            }
        }

        if let gender = manifest.voice.gender {
            if !Self.validGenders.contains(gender) {
                issues.append(VoxIssue(
                    severity: .error,
                    message: "Invalid gender value '\(gender)'. Must be one of: male, female, nonbinary, neutral",
                    field: "voice.gender"
                ))
            }
        }

        if let referenceAudio = manifest.referenceAudio {
            for (index, entry) in referenceAudio.enumerated() {
                if entry.file.trimmingCharacters(in: .whitespaces).isEmpty {
                    issues.append(VoxIssue(
                        severity: .error,
                        message: "Reference audio entry at index \(index) has an empty file path",
                        field: "reference_audio[\(index)].file"
                    ))
                }
            }
        }
    }

    // MARK: - Embedding Entries

    private func validateEmbeddingEntries(_ issues: inout [VoxIssue]) {
        guard let entries = manifest.embeddingEntries else { return }

        for (key, entry) in entries {
            if entry.model.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(VoxIssue(
                    severity: .error,
                    message: "model must not be empty",
                    field: "embeddings.\(key)"
                ))
            }

            let file = entry.file.trimmingCharacters(in: .whitespaces)
            if file.isEmpty {
                issues.append(VoxIssue(
                    severity: .error,
                    message: "file must not be empty",
                    field: "embeddings.\(key)"
                ))
            } else if !file.hasPrefix("embeddings/") {
                issues.append(VoxIssue(
                    severity: .error,
                    message: "file must start with 'embeddings/' (got '\(file)')",
                    field: "embeddings.\(key)"
                ))
            }
        }
    }

    // MARK: - Bundle Completeness

    private func validateBundleCompleteness(_ issues: inout [VoxIssue]) {
        if let entries = manifest.embeddingEntries {
            for (key, entry) in entries {
                if self[entry.file] == nil {
                    issues.append(VoxIssue(
                        severity: .warning,
                        message: "Declared file '\(entry.file)' is missing from the archive",
                        field: "embeddings.\(key)"
                    ))
                }
            }
        }

        if let refAudio = manifest.referenceAudio {
            for entry in refAudio {
                if self[entry.file] == nil {
                    issues.append(VoxIssue(
                        severity: .warning,
                        message: "Declared file '\(entry.file)' is missing from the archive",
                        field: "reference_audio"
                    ))
                }
            }
        }
    }

    // MARK: - Provenance Validation (v0.3.0)

    private func validateProvenance(_ issues: inout [VoxIssue]) {
        guard let provenance = manifest.provenance else { return }

        if let method = provenance.method {
            if !Self.knownMethods.contains(method) {
                issues.append(VoxIssue(
                    severity: .warning,
                    message: "Unknown provenance method '\(method)'. Known values: designed, synthesized, cloned, preset, hybrid",
                    field: "provenance.method"
                ))
            }

            if method == "cloned" {
                // MUST: Cloned voices require source traceability
                if provenance.source == nil || provenance.source?.isEmpty == true {
                    issues.append(VoxIssue(
                        severity: .error,
                        message: "Cloned voices must have provenance.source with at least one entry for traceability",
                        field: "provenance.source"
                    ))
                }

                // MUST: Cloned voices require explicit consent
                let validCloneConsent: Set<String> = ["self", "granted"]
                if let consent = provenance.consent {
                    if !validCloneConsent.contains(consent) {
                        issues.append(VoxIssue(
                            severity: .error,
                            message: "Cloned voices require consent of 'self' or 'granted', got '\(consent)'",
                            field: "provenance.consent"
                        ))
                    }
                } else {
                    issues.append(VoxIssue(
                        severity: .error,
                        message: "Cloned voices require consent of 'self' or 'granted', but consent is nil",
                        field: "provenance.consent"
                    ))
                }
            }
        }
    }

    // MARK: - Reference Audio Model Tag Validation (v0.3.0)

    private func validateReferenceAudioModelTags(_ issues: inout [VoxIssue]) {
        guard let clips = manifest.referenceAudio else { return }
        let embeddingModels: Set<String> = Set(
            manifest.embeddingEntries?.values.map { $0.model.lowercased() } ?? []
        )

        for (index, clip) in clips.enumerated() {
            guard let clipModel = clip.model else { continue }

            let hasMatch = embeddingModels.contains(where: { embModel in
                embModel.contains(clipModel.lowercased()) || clipModel.lowercased().contains(embModel)
            })

            if !hasMatch {
                issues.append(VoxIssue(
                    severity: .warning,
                    message: "Model-tagged reference audio '\(clipModel)' has no matching embeddings entry",
                    field: "reference_audio[\(index)].model"
                ))
            }
        }
    }

    // MARK: - Helpers

    internal static func isValidUUIDv4(_ string: String) -> Bool {
        let lowercased = string.lowercased()
        guard let regex = try? NSRegularExpression(pattern: uuidV4Pattern) else {
            return false
        }
        let range = NSRange(lowercased.startIndex..., in: lowercased)
        return regex.firstMatch(in: lowercased, range: range) != nil
    }
}
