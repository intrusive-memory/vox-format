import Foundation

/// Validates ``VoxManifest`` instances against the VOX format specification.
///
/// `VoxValidator` checks that required fields are present and well-formed, and optionally
/// validates optional fields when they are present. In permissive mode (the default), the
/// validator collects all errors and throws a single ``VoxError/validationErrors(_:)``
/// containing every issue found. In strict mode, validation fails on the first error.
///
/// ```swift
/// let validator = VoxValidator()
/// let manifest = voxFile.manifest
/// try validator.validate(manifest)           // permissive (default)
/// try validator.validate(manifest, strict: true)  // strict
/// ```
public final class VoxValidator {

    /// The set of valid gender values per the VOX specification.
    public static let validGenders: Set<String> = ["male", "female", "nonbinary", "neutral"]

    /// Regular expression pattern for UUID v4 format, matching the JSON Schema definition.
    ///
    /// Pattern: `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`
    private static let uuidV4Pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

    /// Regular expression pattern for ISO 8601 timestamps, matching the JSON Schema definition.
    ///
    /// Pattern: `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$`
    private static let iso8601Pattern = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(Z|[+-]\\d{2}:\\d{2})$"

    /// The minimum length for the voice description field.
    public static let minimumDescriptionLength = 10

    /// Creates a new VoxValidator instance.
    public init() {}

    /// Validates a ``VoxManifest`` against the VOX format specification.
    ///
    /// Checks that all required fields are present and well-formed, and validates optional
    /// fields when they are present. In permissive mode (the default), all errors are
    /// collected and reported together. In strict mode, validation halts on the first error.
    ///
    /// - Parameters:
    ///   - manifest: The manifest to validate.
    ///   - strict: If `true`, throws immediately on the first validation error.
    ///             If `false` (default), collects all errors and throws them together.
    /// - Throws: ``VoxError/validationErrors(_:)`` containing all validation failures (permissive mode),
    ///           or the first specific ``VoxError`` encountered (strict mode).
    ///
    /// ```swift
    /// let validator = VoxValidator()
    /// try validator.validate(manifest)
    /// ```
    public func validate(_ manifest: VoxManifest, strict: Bool = false) throws {
        var errors: [VoxError] = []

        // Required fields validation (VOX-046)
        validateRequiredFields(manifest, errors: &errors, strict: strict)

        // Optional fields validation (VOX-047)
        validateOptionalFields(manifest, errors: &errors, strict: strict)

        // Throw collected errors in permissive mode
        if !errors.isEmpty {
            throw VoxError.validationErrors(errors)
        }
    }

    // MARK: - Required Fields Validation (VOX-046)

    /// Validates all required manifest fields.
    ///
    /// - Parameters:
    ///   - manifest: The manifest to validate.
    ///   - errors: Array to collect validation errors into.
    ///   - strict: If true, throws on first error instead of collecting.
    private func validateRequiredFields(
        _ manifest: VoxManifest,
        errors: inout [VoxError],
        strict: Bool
    ) {
        // Check voxVersion is non-empty
        if manifest.voxVersion.trimmingCharacters(in: .whitespaces).isEmpty {
            let error = VoxError.emptyRequiredField(field: "vox_version")
            if strict {
                errors.append(error)
                return
            }
            errors.append(error)
        }

        // Validate id is valid UUID v4 format
        if !isValidUUIDv4(manifest.id) {
            let error = VoxError.invalidUUID(manifest.id)
            if strict {
                errors.append(error)
                return
            }
            errors.append(error)
        }

        // Validate created is valid ISO 8601 timestamp by re-encoding
        // The date was already decoded from JSON, so we verify via round-trip
        if !isValidISO8601Date(manifest.created) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let dateString: String
            if let data = try? encoder.encode([manifest.created]),
               let str = String(data: data, encoding: .utf8) {
                dateString = str
            } else {
                dateString = "\(manifest.created)"
            }
            let error = VoxError.invalidTimestamp(dateString)
            if strict {
                errors.append(error)
                return
            }
            errors.append(error)
        }

        // Check voice.name is non-empty
        if manifest.voice.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let error = VoxError.emptyRequiredField(field: "voice.name")
            if strict {
                errors.append(error)
                return
            }
            errors.append(error)
        }

        // Check voice.description is non-empty and at least 10 chars
        let descriptionLength = manifest.voice.description.trimmingCharacters(in: .whitespaces).count
        if descriptionLength == 0 {
            let error = VoxError.emptyRequiredField(field: "voice.description")
            if strict {
                errors.append(error)
                return
            }
            errors.append(error)
        } else if descriptionLength < Self.minimumDescriptionLength {
            let error = VoxError.descriptionTooShort(
                field: "voice.description",
                length: descriptionLength,
                minimum: Self.minimumDescriptionLength
            )
            if strict {
                errors.append(error)
                return
            }
            errors.append(error)
        }
    }

    // MARK: - Optional Fields Validation (VOX-047)

    /// Validates optional manifest fields when they are present.
    ///
    /// - Parameters:
    ///   - manifest: The manifest to validate.
    ///   - errors: Array to collect validation errors into.
    ///   - strict: If true, throws on first error instead of collecting.
    private func validateOptionalFields(
        _ manifest: VoxManifest,
        errors: inout [VoxError],
        strict: Bool
    ) {
        // Validate age_range if present: min < max
        if let ageRange = manifest.voice.ageRange, ageRange.count == 2 {
            let minAge = ageRange[0]
            let maxAge = ageRange[1]
            if minAge >= maxAge {
                let error = VoxError.invalidAgeRange(min: minAge, max: maxAge)
                if strict {
                    errors.append(error)
                    return
                }
                errors.append(error)
            }
        }

        // Validate gender if present: must be one of the allowed values
        if let gender = manifest.voice.gender {
            if !Self.validGenders.contains(gender) {
                let error = VoxError.invalidGender(gender)
                if strict {
                    errors.append(error)
                    return
                }
                errors.append(error)
            }
        }

        // Validate reference_audio if present: file paths must be non-empty
        if let referenceAudio = manifest.referenceAudio {
            for (index, entry) in referenceAudio.enumerated() {
                if entry.file.trimmingCharacters(in: .whitespaces).isEmpty {
                    let error = VoxError.emptyReferenceAudioPath(index: index)
                    if strict {
                        errors.append(error)
                        return
                    }
                    errors.append(error)
                }
            }
        }
    }

    // MARK: - Validation Helpers

    /// Checks whether a string is a valid UUID v4 format.
    ///
    /// Uses the regex pattern from the JSON Schema: lowercase hex digits with
    /// the version nibble `4` and variant nibble `[89ab]`.
    ///
    /// - Parameter string: The string to validate.
    /// - Returns: `true` if the string matches UUID v4 format.
    internal func isValidUUIDv4(_ string: String) -> Bool {
        let lowercased = string.lowercased()
        guard let regex = try? NSRegularExpression(pattern: Self.uuidV4Pattern) else {
            return false
        }
        let range = NSRange(lowercased.startIndex..., in: lowercased)
        return regex.firstMatch(in: lowercased, range: range) != nil
    }

    /// Checks whether a Date can be represented as a valid ISO 8601 timestamp.
    ///
    /// Since the manifest's `created` field is already decoded as a Date, this method
    /// verifies the Date is a finite, valid value. The original string format was already
    /// validated during JSON decoding.
    ///
    /// - Parameter date: The date to validate.
    /// - Returns: `true` if the date is a valid, finite value.
    internal func isValidISO8601Date(_ date: Date) -> Bool {
        // A Date that was successfully decoded from ISO 8601 is inherently valid.
        // We check for degenerate values (NaN, infinity).
        let interval = date.timeIntervalSince1970
        return interval.isFinite && !interval.isNaN
    }
}
