import XCTest
@testable import VoxFormat

final class ValidatorTests: XCTestCase {

    // MARK: - Helper: Create valid minimal VoxFile

    private func validMinimalVoxFile() -> VoxFile {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "Narrator",
                description: "A warm, clear narrator voice with neutral accent suitable for audiobooks and documentaries."
            )
        )
        return VoxFile(manifest: manifest)
    }

    // MARK: - Helper: Locate example files

    private func exampleURL(_ relativePath: String) -> URL {
        let swiftDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return swiftDir.appendingPathComponent(relativePath)
    }

    // MARK: - Successful Validation Tests

    func testValidatesMinimalManifestSuccessfully() throws {
        let vox = validMinimalVoxFile()
        let issues = vox.validate()
        let errors = issues.filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, "Minimal manifest should validate without errors")
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

        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidatesExampleMinimalVox() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Example file narrator.vox not found at \(url.path)")
            return
        }

        let voxFile = try VoxFile(contentsOf: url)
        let errors = voxFile.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidatesExampleNarratorWithContextVox() throws {
        let url = exampleURL("examples/character/narrator-with-context.vox")
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Example file narrator-with-context.vox not found")
            return
        }

        let voxFile = try VoxFile(contentsOf: url)
        let errors = voxFile.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidatesExampleCrossPlatformVox() throws {
        let url = exampleURL("examples/multi-engine/cross-platform.vox")
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Example file cross-platform.vox not found")
            return
        }

        let voxFile = try VoxFile(contentsOf: url)
        let errors = voxFile.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty)
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

            let voxFile = try VoxFile(contentsOf: url)
            let errors = voxFile.validate().filter { $0.severity == .error }
            XCTAssertTrue(errors.isEmpty, "Validation should pass for \(example)")
        }
    }

    // MARK: - Required Field Rejection Tests

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

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasVersionError = issues.contains { $0.severity == .error && $0.field == "vox_version" }
        XCTAssertTrue(hasVersionError, "Should include empty vox_version error")
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

        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertFalse(errors.isEmpty)
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

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasUUIDError = issues.contains { $0.severity == .error && $0.field == "id" }
        XCTAssertTrue(hasUUIDError, "Should include invalidUUID error")
    }

    func testRejectsUUIDWithUppercase() throws {
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
        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        let hasUUIDError = errors.contains { $0.field == "id" }
        XCTAssertFalse(hasUUIDError, "Uppercase UUID should be accepted")
    }

    func testRejectsUUIDv1Format() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-1f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters."
            )
        )

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasUUIDError = issues.contains { $0.severity == .error && $0.field == "id" }
        XCTAssertTrue(hasUUIDError, "Should reject UUID v1 format")
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

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasNameError = issues.contains { $0.severity == .error && $0.field == "voice.name" }
        XCTAssertTrue(hasNameError, "Should include empty voice.name error")
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

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasDescError = issues.contains { $0.severity == .error && $0.field == "voice.description" }
        XCTAssertTrue(hasDescError, "Should include empty voice.description error")
    }

    func testRejectsTooShortVoiceDescription() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "Short"
            )
        )

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasShortError = issues.contains { $0.severity == .error && $0.field == "voice.description" }
        XCTAssertTrue(hasShortError, "Should include descriptionTooShort error")
    }

    // MARK: - Optional Field Rejection Tests

    func testRejectsInvalidAgeRange() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters.",
                ageRange: [30, 20]
            )
        )

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasAgeError = issues.contains { $0.severity == .error && $0.field == "voice.age_range" }
        XCTAssertTrue(hasAgeError, "Should include invalidAgeRange error for [30, 20]")
    }

    func testRejectsEqualAgeRange() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters.",
                ageRange: [30, 30]
            )
        )

        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertFalse(errors.isEmpty)
    }

    func testRejectsInvalidGender() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "A valid description with enough characters.",
                gender: "other"
            )
        )

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasGenderError = issues.contains { $0.severity == .error && $0.field == "voice.gender" }
        XCTAssertTrue(hasGenderError, "Should include invalidGender error for 'other'")
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

            let vox = VoxFile(manifest: manifest)
            let errors = vox.validate().filter { $0.severity == .error }
            XCTAssertTrue(errors.isEmpty, "Gender '\(gender)' should be accepted")
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
                    file: "",
                    transcript: "Some transcript"
                )
            ]
        )

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasPathError = issues.contains { $0.severity == .error && ($0.field?.contains("reference_audio") ?? false) }
        XCTAssertTrue(hasPathError, "Should include emptyReferenceAudioPath error")
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

        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - Multiple Error Collection Tests

    func testCollectsMultipleErrors() throws {
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

        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertGreaterThanOrEqual(
            errors.count, 4,
            "Should collect multiple validation errors, got \(errors.count)"
        )
    }

    // MARK: - UUID Validation Helper Tests

    func testUUIDv4ValidationHelperAcceptsValid() throws {
        let validUUIDs = [
            "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            "cccb2a22-1d46-440f-bb8e-9fb93963e199",
            "7ca7b257-e94a-43ae-adae-c60116fb8a8a",
            "12345678-1234-4234-8234-123456789abc"
        ]

        for uuid in validUUIDs {
            XCTAssertTrue(
                VoxFile.isValidUUIDv4(uuid),
                "'\(uuid)' should be accepted as valid UUID v4"
            )
        }
    }

    func testUUIDv4ValidationHelperRejectsInvalid() throws {
        let invalidUUIDs = [
            "not-a-uuid",
            "12345678-1234-1234-1234-123456789abc",
            "12345678-1234-5234-8234-123456789abc",
            "ZZZZZZZZ-ZZZZ-4ZZZ-8ZZZ-ZZZZZZZZZZZZ",
            "",
            "12345678-1234-4234-0234-123456789abc"
        ]

        for uuid in invalidUUIDs {
            XCTAssertFalse(
                VoxFile.isValidUUIDv4(uuid),
                "'\(uuid)' should be rejected as invalid UUID v4"
            )
        }
    }

    // MARK: - Nil Optional Fields Accepted

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

        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - isValid convenience

    func testIsValidConvenience() throws {
        let valid = validMinimalVoxFile()
        XCTAssertTrue(valid.isValid)

        let invalidManifest = VoxManifest(
            voxVersion: "",
            id: "bad",
            created: Date(),
            voice: VoxManifest.Voice(name: "", description: "")
        )
        let invalid = VoxFile(manifest: invalidManifest)
        XCTAssertFalse(invalid.isValid)
    }

    // MARK: - Ethical Provenance Validation (v0.3.0)

    func testClonedWithoutSourceProducesError() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "ClonedNoSource",
                description: "A cloned voice missing source traceability."
            ),
            provenance: VoxManifest.Provenance(
                method: "cloned",
                consent: "self",
                source: nil
            )
        )
        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasSourceError = issues.contains { $0.severity == .error && $0.field == "provenance.source" }
        XCTAssertTrue(hasSourceError, "Cloned voice without source should produce error")
    }

    func testClonedWithEmptySourceProducesError() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "ClonedEmptySource",
                description: "A cloned voice with empty source array."
            ),
            provenance: VoxManifest.Provenance(
                method: "cloned",
                consent: "granted",
                source: []
            )
        )
        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasSourceError = issues.contains { $0.severity == .error && $0.field == "provenance.source" }
        XCTAssertTrue(hasSourceError, "Cloned voice with empty source should produce error")
    }

    func testClonedWithUnknownConsentProducesError() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "ClonedUnknownConsent",
                description: "A cloned voice with unknown consent status."
            ),
            provenance: VoxManifest.Provenance(
                method: "cloned",
                consent: "unknown",
                source: ["reference/source.wav"]
            )
        )
        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasConsentError = issues.contains { $0.severity == .error && $0.field == "provenance.consent" }
        XCTAssertTrue(hasConsentError, "Cloned voice with unknown consent should produce error")
    }

    func testClonedWithNilConsentProducesError() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "ClonedNilConsent",
                description: "A cloned voice with nil consent status."
            ),
            provenance: VoxManifest.Provenance(
                method: "cloned",
                consent: nil,
                source: ["reference/source.wav"]
            )
        )
        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        let hasConsentError = issues.contains { $0.severity == .error && $0.field == "provenance.consent" }
        XCTAssertTrue(hasConsentError, "Cloned voice with nil consent should produce error")
    }

    func testClonedWithSelfConsentAndSourcePasses() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "ClonedValid",
                description: "A properly consented cloned voice."
            ),
            provenance: VoxManifest.Provenance(
                method: "cloned",
                consent: "self",
                source: ["reference/my-voice.wav"]
            )
        )
        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, "Cloned voice with self consent and source should pass")
    }

    func testClonedWithGrantedConsentAndSourcePasses() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "ClonedGranted",
                description: "A cloned voice with granted consent."
            ),
            provenance: VoxManifest.Provenance(
                method: "cloned",
                consent: "granted",
                source: ["reference/actor-recording.wav"]
            )
        )
        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, "Cloned voice with granted consent and source should pass")
    }

    func testSynthesizedMethodPasses() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Synthesized",
                description: "A synthesized voice from model generation."
            ),
            provenance: VoxManifest.Provenance(
                method: "synthesized",
                engine: "qwen3-tts-1.7b"
            )
        )
        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, "Synthesized method should validate without errors")
    }

    func testModelTaggedAudioWithoutMatchingEmbeddingProducesWarning() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "OrphanModel",
                description: "Voice with model-tagged audio but no embedding."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/sample.wav",
                    transcript: "Test",
                    model: "SomeModel/That-Does-Not-Exist"
                )
            ]
        )
        let vox = VoxFile(manifest: manifest)
        let warnings = vox.validate().filter { $0.severity == .warning && ($0.field?.contains("model") ?? false) }
        XCTAssertFalse(warnings.isEmpty, "Model-tagged audio without matching embedding should produce warning")
    }

    func testModelTaggedAudioWithMatchingEmbeddingNoWarning() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "MatchedModel",
                description: "Voice with model-tagged audio and matching embedding."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/sample.wav",
                    transcript: "Test",
                    model: "Qwen/Qwen3-TTS-12Hz-0.6B"
                )
            ],
            embeddingEntries: [
                "qwen3-tts-0.6b": VoxManifest.EmbeddingEntry(
                    model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                    engine: "qwen3-tts",
                    file: "embeddings/qwen3-tts/0.6b/clone-prompt.bin"
                )
            ]
        )
        let vox = VoxFile(manifest: manifest)
        let modelWarnings = vox.validate().filter { $0.severity == .warning && ($0.field?.contains("model") ?? false) }
        XCTAssertTrue(modelWarnings.isEmpty, "Model-tagged audio with matching embedding should not produce model warning")
    }

    func testUnknownMethodProducesWarning() throws {
        let manifest = VoxManifest(
            voxVersion: "0.3.0",
            id: "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "UnknownMethod",
                description: "Voice with unknown provenance method."
            ),
            provenance: VoxManifest.Provenance(
                method: "alien-technology"
            )
        )
        let vox = VoxFile(manifest: manifest)
        let warnings = vox.validate().filter { $0.severity == .warning && $0.field == "provenance.method" }
        XCTAssertFalse(warnings.isEmpty, "Unknown method should produce warning")
    }

    // MARK: - Error Description Tests

    func testValidationIssueDescriptionsAreDescriptive() throws {
        let manifest = VoxManifest(
            voxVersion: "",
            id: "bad-uuid",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "",
                description: "Short"
            )
        )

        let vox = VoxFile(manifest: manifest)
        let issues = vox.validate()
        XCTAssertFalse(issues.isEmpty, "Should have validation issues")
        for issue in issues {
            XCTAssertFalse(issue.description.isEmpty, "Issue should have a description")
        }
    }
}
