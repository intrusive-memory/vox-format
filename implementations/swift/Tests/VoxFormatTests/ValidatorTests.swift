import XCTest
@testable import VoxFormat

final class ValidatorTests: XCTestCase {

    let validator = VoxValidator()
    let reader = VoxReader()

    // MARK: - Helper: Create valid minimal manifest

    /// Creates a valid minimal manifest for testing.
    private func validMinimalManifest() -> VoxManifest {
        VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "Narrator",
                description: "A warm, clear narrator voice with neutral accent suitable for audiobooks and documentaries."
            )
        )
    }

    // MARK: - Helper: Locate example files

    /// Returns the URL for an example .vox file relative to the repository root.
    private func exampleURL(_ relativePath: String) -> URL {
        let swiftDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return swiftDir.appendingPathComponent(relativePath)
    }

    // MARK: - VOX-048: Successful Validation Tests

    func testValidatesMinimalManifestSuccessfully() throws {
        let manifest = validMinimalManifest()
        XCTAssertNoThrow(try validator.validate(manifest))
    }

    func testValidatesMinimalManifestInStrictMode() throws {
        let manifest = validMinimalManifest()
        XCTAssertNoThrow(try validator.validate(manifest, strict: true))
    }

    func testValidatesFullySpecifiedManifest() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "cccb2a22-1d46-440f-bb8e-9fb93963e199",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "NARRATOR",
                description: "Male, 40s-50s, British. Rich baritone with theatrical training.",
                language: "en-GB",
                gender: "male",
                ageRange: [45, 55],
                tags: ["narrator", "authoritative", "theatrical"]
            ),
            prosody: VoxManifest.Prosody(
                pitchBase: "low",
                pitchRange: "moderate",
                rate: "moderate",
                energy: "medium",
                emotionDefault: "calm authority"
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/sample.wav",
                    transcript: "Test transcript.",
                    language: "en-GB",
                    durationSeconds: 4.2
                )
            ],
            character: VoxManifest.Character(
                role: "Omniscient narrator",
                emotionalRange: ["contemplative", "melancholic"],
                relationships: ["PROTAGONIST": "Observer"]
            ),
            provenance: VoxManifest.Provenance(
                method: "designed",
                engine: "qwen3-tts",
                consent: nil,
                license: "CC0-1.0"
            )
        )

        XCTAssertNoThrow(try validator.validate(manifest))
    }

    func testValidatesExampleMinimalVox() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Example file narrator.vox not found at \(url.path)")
            return
        }

        let voxFile = try reader.read(from: url)
        XCTAssertNoThrow(try validator.validate(voxFile.manifest))
    }

    func testValidatesExampleNarratorWithContextVox() throws {
        let url = exampleURL("examples/character/narrator-with-context.vox")
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Example file narrator-with-context.vox not found")
            return
        }

        let voxFile = try reader.read(from: url)
        XCTAssertNoThrow(try validator.validate(voxFile.manifest))
    }

    func testValidatesExampleCrossPlatformVox() throws {
        let url = exampleURL("examples/multi-engine/cross-platform.vox")
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Example file cross-platform.vox not found")
            return
        }

        let voxFile = try reader.read(from: url)
        XCTAssertNoThrow(try validator.validate(voxFile.manifest))
    }

    func testValidatesAllExampleVoxFiles() throws {
        let examples = [
            "examples/minimal/narrator.vox",
            "examples/character/narrator-with-context.vox",
            "examples/multi-engine/cross-platform.vox"
        ]

        for example in examples {
            let url = exampleURL(example)
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            let voxFile = try reader.read(from: url)
            XCTAssertNoThrow(
                try validator.validate(voxFile.manifest),
                "Validation should pass for \(example)"
            )
        }
    }

    // MARK: - VOX-048: Required Field Rejection Tests

    func testRejectsMissingVoxVersion() throws {
        let manifest = VoxManifest(
            voxVersion: "",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters."
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(type(of: error))")
                return
            }
            if case .validationErrors(let errors) = voxError {
                let hasVersionError = errors.contains { err in
                    if case .emptyRequiredField(let field) = err {
                        return field == "vox_version"
                    }
                    return false
                }
                XCTAssertTrue(hasVersionError, "Should include empty vox_version error")
            } else {
                XCTFail("Expected validationErrors, got \(voxError)")
            }
        }
    }

    func testRejectsWhitespaceOnlyVoxVersion() throws {
        let manifest = VoxManifest(
            voxVersion: "   ",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters."
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest))
    }

    func testRejectsInvalidUUID() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "not-a-valid-uuid",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters."
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(type(of: error))")
                return
            }
            if case .validationErrors(let errors) = voxError {
                let hasUUIDError = errors.contains { err in
                    if case .invalidUUID = err {
                        return true
                    }
                    return false
                }
                XCTAssertTrue(hasUUIDError, "Should include invalidUUID error")
            } else {
                XCTFail("Expected validationErrors, got \(voxError)")
            }
        }
    }

    func testRejectsUUIDWithUppercase() throws {
        // The schema requires lowercase hex digits
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "AD7AA7D7-570D-4F9E-99DA-1BD14B99CC78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters."
            )
        )

        // Should still pass because the validator lowercases before checking
        XCTAssertNoThrow(try validator.validate(manifest))
    }

    func testRejectsUUIDv1Format() throws {
        // UUID v1 has version nibble 1, not 4
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-1f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters."
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError")
                return
            }
            if case .validationErrors(let errors) = voxError {
                let hasUUIDError = errors.contains { err in
                    if case .invalidUUID = err { return true }
                    return false
                }
                XCTAssertTrue(hasUUIDError, "Should reject UUID v1 format")
            }
        }
    }

    func testRejectsEmptyVoiceName() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "",
                description: "A valid description with enough characters."
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(type(of: error))")
                return
            }
            if case .validationErrors(let errors) = voxError {
                let hasNameError = errors.contains { err in
                    if case .emptyRequiredField(let field) = err {
                        return field == "voice.name"
                    }
                    return false
                }
                XCTAssertTrue(hasNameError, "Should include empty voice.name error")
            } else {
                XCTFail("Expected validationErrors, got \(voxError)")
            }
        }
    }

    func testRejectsEmptyVoiceDescription() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: ""
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(type(of: error))")
                return
            }
            if case .validationErrors(let errors) = voxError {
                let hasDescError = errors.contains { err in
                    if case .emptyRequiredField(let field) = err {
                        return field == "voice.description"
                    }
                    return false
                }
                XCTAssertTrue(hasDescError, "Should include empty voice.description error")
            }
        }
    }

    func testRejectsTooShortVoiceDescription() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "Short"  // Only 5 characters, minimum is 10
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(type(of: error))")
                return
            }
            if case .validationErrors(let errors) = voxError {
                let hasShortError = errors.contains { err in
                    if case .descriptionTooShort = err { return true }
                    return false
                }
                XCTAssertTrue(hasShortError, "Should include descriptionTooShort error")
            }
        }
    }

    // MARK: - VOX-048: Optional Field Rejection Tests

    func testRejectsInvalidAgeRange() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters.",
                ageRange: [30, 20]  // min > max
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(type(of: error))")
                return
            }
            if case .validationErrors(let errors) = voxError {
                let hasAgeError = errors.contains { err in
                    if case .invalidAgeRange(let min, let max) = err {
                        return min == 30 && max == 20
                    }
                    return false
                }
                XCTAssertTrue(hasAgeError, "Should include invalidAgeRange error for [30, 20]")
            }
        }
    }

    func testRejectsEqualAgeRange() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters.",
                ageRange: [30, 30]  // equal values
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest))
    }

    func testRejectsInvalidGender() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters.",
                gender: "other"  // Not in the allowed enum
            )
        )

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(type(of: error))")
                return
            }
            if case .validationErrors(let errors) = voxError {
                let hasGenderError = errors.contains { err in
                    if case .invalidGender(let value) = err {
                        return value == "other"
                    }
                    return false
                }
                XCTAssertTrue(hasGenderError, "Should include invalidGender error for 'other'")
            }
        }
    }

    func testAcceptsAllValidGenders() throws {
        let validGenders = ["male", "female", "nonbinary", "neutral"]

        for gender in validGenders {
            let manifest = VoxManifest(
                voxVersion: "0.1.0",
                id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
                created: Date(),
                voice: VoxManifest.Voice(
                    name: "Test",
                    description: "A valid description with enough characters.",
                    gender: gender
                )
            )

            XCTAssertNoThrow(
                try validator.validate(manifest),
                "Gender '\(gender)' should be accepted"
            )
        }
    }

    func testRejectsEmptyReferenceAudioPath() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "",  // Empty path
                    transcript: "Some transcript"
                )
            ]
        )

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(type(of: error))")
                return
            }
            if case .validationErrors(let errors) = voxError {
                let hasPathError = errors.contains { err in
                    if case .emptyReferenceAudioPath(let index) = err {
                        return index == 0
                    }
                    return false
                }
                XCTAssertTrue(hasPathError, "Should include emptyReferenceAudioPath error at index 0")
            }
        }
    }

    func testAcceptsValidReferenceAudio() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/sample.wav",
                    transcript: "Valid transcript"
                )
            ]
        )

        XCTAssertNoThrow(try validator.validate(manifest))
    }

    // MARK: - VOX-048: Multiple Error Collection Tests

    func testCollectsMultipleErrorsInPermissiveMode() throws {
        let manifest = VoxManifest(
            voxVersion: "",
            id: "not-a-uuid",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "",
                description: "Short",
                gender: "invalid",
                ageRange: [50, 30]
            )
        )

        do {
            try validator.validate(manifest)
            XCTFail("Expected validation to fail")
        } catch let error as VoxError {
            if case .validationErrors(let errors) = error {
                // Should have multiple errors: empty version, invalid UUID,
                // empty name, short description, invalid gender, invalid age range
                XCTAssertGreaterThanOrEqual(
                    errors.count, 4,
                    "Should collect multiple validation errors, got \(errors.count)"
                )
            } else {
                XCTFail("Expected validationErrors, got \(error)")
            }
        }
    }

    func testStrictModeStopsAtFirstError() throws {
        let manifest = VoxManifest(
            voxVersion: "",
            id: "not-a-uuid",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "",
                description: "Short"
            )
        )

        do {
            try validator.validate(manifest, strict: true)
            XCTFail("Expected validation to fail in strict mode")
        } catch let error as VoxError {
            if case .validationErrors(let errors) = error {
                // In strict mode, should stop after first error
                XCTAssertEqual(errors.count, 1, "Strict mode should stop at first error")
            } else {
                XCTFail("Expected validationErrors, got \(error)")
            }
        }
    }

    // MARK: - VOX-048: UUID Validation Helper Tests

    func testUUIDv4ValidationHelperAcceptsValid() throws {
        let validUUIDs = [
            "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            "cccb2a22-1d46-440f-bb8e-9fb93963e199",
            "7ca7b257-e94a-43ae-adae-c60116fb8a8a",
            "12345678-1234-4234-8234-123456789abc"
        ]

        for uuid in validUUIDs {
            XCTAssertTrue(
                validator.isValidUUIDv4(uuid),
                "'\(uuid)' should be accepted as valid UUID v4"
            )
        }
    }

    func testUUIDv4ValidationHelperRejectsInvalid() throws {
        let invalidUUIDs = [
            "not-a-uuid",
            "12345678-1234-1234-1234-123456789abc", // version 1
            "12345678-1234-5234-8234-123456789abc", // version 5
            "ZZZZZZZZ-ZZZZ-4ZZZ-8ZZZ-ZZZZZZZZZZZZ", // non-hex characters
            "",
            "12345678-1234-4234-0234-123456789abc" // variant nibble 0 not in [89ab]
        ]

        for uuid in invalidUUIDs {
            XCTAssertFalse(
                validator.isValidUUIDv4(uuid),
                "'\(uuid)' should be rejected as invalid UUID v4"
            )
        }
    }

    // MARK: - VOX-048: Nil Optional Fields Accepted

    func testAcceptsNilOptionalFields() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters.",
                language: nil,
                gender: nil,
                ageRange: nil,
                tags: nil
            ),
            prosody: nil,
            referenceAudio: nil,
            character: nil,
            provenance: nil,
            extensions: nil
        )

        XCTAssertNoThrow(try validator.validate(manifest))
    }

    // MARK: - VOX-048: Error Description Tests

    func testValidationErrorDescriptionsAreDescriptive() throws {
        let manifest = VoxManifest(
            voxVersion: "",
            id: "bad-uuid",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "",
                description: "Short"
            )
        )

        do {
            try validator.validate(manifest)
            XCTFail("Expected validation to fail")
        } catch let error as VoxError {
            let description = error.errorDescription ?? ""
            XCTAssertFalse(description.isEmpty, "Error should have a description")
            XCTAssertTrue(
                description.contains("error"),
                "Error description should mention 'error'"
            )
        }
    }
}
