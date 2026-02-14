import XCTest
@testable import VoxFormat
import Foundation

/// Integration tests using real .vox files from examples directory
final class IntegrationTests: XCTestCase {

    // MARK: - Test Resources

    private var examplesPath: URL {
        // Build absolute path to examples directory
        // #filePath gives us the full path to this test file
        // /Users/stovak/Projects/vox-format/implementations/swift/Tests/VoxFormatTests/IntegrationTests.swift
        let currentFile = URL(fileURLWithPath: #filePath)
        let testsDir = currentFile.deletingLastPathComponent().deletingLastPathComponent() // Remove file and VoxFormatTests
        let swiftDir = testsDir.deletingLastPathComponent() // Remove Tests
        let implementationsDir = swiftDir.deletingLastPathComponent() // Remove swift
        let projectRoot = implementationsDir.deletingLastPathComponent() // Remove implementations
        return projectRoot.appendingPathComponent("examples")
    }

    private func exampleVoxURL(path: String) -> URL {
        return examplesPath.appendingPathComponent(path)
    }

    // MARK: - Reading Tests

    func testReadAllExamples() throws {
        let exampleFiles: [(path: String, expectedName: String)] = [
            ("minimal/narrator.vox", "Narrator"),
            ("character/narrator-with-context.vox", "NARRATOR"),
            ("multi-engine/cross-platform.vox", "VERSATILE"),
            ("library/narrators/audiobook.vox", "Audiobook Narrator"),
            ("library/narrators/documentary.vox", "Documentary Narrator"),
            ("library/narrators/storytelling.vox", "Storytelling Narrator"),
            ("library/characters/young-protagonist.vox", "Young Protagonist"),
            ("library/characters/wise-mentor.vox", "Wise Mentor"),
            ("library/characters/elderly-sage.vox", "Elderly Sage")
        ]

        let reader = VoxReader()

        for example in exampleFiles {
            let voxURL = exampleVoxURL(path: example.path)

            // Verify file exists
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: voxURL.path),
                "Example file not found: \(example.path)"
            )

            // Read the .vox file
            let voxFile = try reader.read(from: voxURL)

            // Verify VoxFile was returned
            XCTAssertNotNil(voxFile, "Failed to read \(example.path)")

            // Verify manifest was parsed
            XCTAssertNotNil(voxFile.manifest, "No manifest in \(example.path)")

            // Verify voice name matches expected
            XCTAssertEqual(
                voxFile.manifest.voice.name,
                example.expectedName,
                "Unexpected voice name in \(example.path)"
            )

            // Verify required fields
            XCTAssertFalse(voxFile.manifest.voxVersion.isEmpty, "Empty vox_version in \(example.path)")
            XCTAssertFalse(voxFile.manifest.id.isEmpty, "Empty id in \(example.path)")
            XCTAssertFalse(voxFile.manifest.voice.description.isEmpty, "Empty description in \(example.path)")
        }
    }

    // MARK: - Validation Tests

    func testValidateAllExamples() throws {
        let exampleFiles = [
            "minimal/narrator.vox",
            "character/narrator-with-context.vox",
            "multi-engine/cross-platform.vox",
            "library/narrators/audiobook.vox",
            "library/narrators/documentary.vox",
            "library/narrators/storytelling.vox",
            "library/characters/young-protagonist.vox",
            "library/characters/wise-mentor.vox",
            "library/characters/elderly-sage.vox"
        ]

        let reader = VoxReader()
        let validator = VoxValidator()

        for examplePath in exampleFiles {
            let voxURL = exampleVoxURL(path: examplePath)
            let voxFile = try reader.read(from: voxURL)

            // Validate manifest (permissive mode)
            XCTAssertNoThrow(
                try validator.validate(voxFile.manifest),
                "Validation failed for \(examplePath)"
            )

            // Also test strict mode
            XCTAssertNoThrow(
                try validator.validate(voxFile.manifest, strict: true),
                "Strict validation failed for \(examplePath)"
            )
        }
    }

    // MARK: - Roundtrip Tests

    func testRoundtripMinimal() throws {
        let originalURL = exampleVoxURL(path: "minimal/narrator.vox")
        let reader = VoxReader()
        let writer = VoxWriter()

        // Read original
        let originalVoxFile = try reader.read(from: originalURL)

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-minimal-\(UUID().uuidString).vox")
        try writer.write(originalVoxFile, to: tempURL)

        // Read back
        let roundtripVoxFile = try reader.read(from: tempURL)

        // Compare manifests
        assertManifestsEqual(originalVoxFile.manifest, roundtripVoxFile.manifest)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testRoundtripCharacter() throws {
        let originalURL = exampleVoxURL(path: "character/narrator-with-context.vox")
        let reader = VoxReader()
        let writer = VoxWriter()

        // Read original
        let originalVoxFile = try reader.read(from: originalURL)

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-character-\(UUID().uuidString).vox")
        try writer.write(originalVoxFile, to: tempURL)

        // Read back
        let roundtripVoxFile = try reader.read(from: tempURL)

        // Compare manifests
        assertManifestsEqual(originalVoxFile.manifest, roundtripVoxFile.manifest)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testRoundtripContext() throws {
        // Same file as testRoundtripCharacter, but verifying context-specific fields
        let originalURL = exampleVoxURL(path: "character/narrator-with-context.vox")
        let reader = VoxReader()
        let writer = VoxWriter()

        // Read original
        let originalVoxFile = try reader.read(from: originalURL)

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-context-\(UUID().uuidString).vox")
        try writer.write(originalVoxFile, to: tempURL)

        // Read back
        let roundtripVoxFile = try reader.read(from: tempURL)

        // Verify character context fields
        XCTAssertEqual(
            originalVoxFile.manifest.character?.role,
            roundtripVoxFile.manifest.character?.role
        )
        XCTAssertEqual(
            originalVoxFile.manifest.character?.emotionalRange,
            roundtripVoxFile.manifest.character?.emotionalRange
        )
        XCTAssertEqual(
            originalVoxFile.manifest.character?.relationships,
            roundtripVoxFile.manifest.character?.relationships
        )
        XCTAssertEqual(
            originalVoxFile.manifest.character?.source?.work,
            roundtripVoxFile.manifest.character?.source?.work
        )

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testRoundtripMultiEngine() throws {
        let originalURL = exampleVoxURL(path: "multi-engine/cross-platform.vox")
        let reader = VoxReader()
        let writer = VoxWriter()

        // Read original
        let originalVoxFile = try reader.read(from: originalURL)

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-multiengine-\(UUID().uuidString).vox")
        try writer.write(originalVoxFile, to: tempURL)

        // Read back
        let roundtripVoxFile = try reader.read(from: tempURL)

        // Verify extensions are preserved
        XCTAssertEqual(
            originalVoxFile.manifest.extensions?.keys.sorted(),
            roundtripVoxFile.manifest.extensions?.keys.sorted()
        )

        // Compare manifests
        assertManifestsEqual(originalVoxFile.manifest, roundtripVoxFile.manifest)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Error Handling Tests

    func testInvalidManifest() throws {
        // Create a .vox file with missing required field
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid-manifest-\(UUID().uuidString).vox")

        let invalidJSON = """
        {
          "vox_version": "0.1.0",
          "id": "12345678-1234-4234-8234-123456789abc",
          "created": "2026-02-13T12:00:00Z",
          "voice": {
            "name": "Invalid"
          }
        }
        """

        // Create ZIP with invalid manifest
        let writer = VoxWriter()
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Invalid",
                description: "" // Empty description - should fail validation
            )
        )
        let voxFile = VoxFile(manifest: manifest)
        try writer.write(voxFile, to: tempURL)

        // Try to read and validate - should throw
        let reader = VoxReader()
        let validator = VoxValidator()
        let invalidVoxFile = try reader.read(from: tempURL)

        XCTAssertThrowsError(
            try validator.validate(invalidVoxFile.manifest),
            "Should throw error for empty description"
        ) { error in
            XCTAssertTrue(
                error is VoxError,
                "Error should be VoxError type"
            )
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testInvalidZip() throws {
        // Create a non-ZIP file with .vox extension
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-zip-\(UUID().uuidString).vox")

        try "This is not a ZIP file".write(to: tempURL, atomically: true, encoding: .utf8)

        let reader = VoxReader()

        XCTAssertThrowsError(
            try reader.read(from: tempURL),
            "Should throw error for invalid ZIP"
        ) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(error)")
                return
            }
            if case .invalidZipFile = voxError {
                // Expected error
            } else {
                XCTFail("Expected VoxError.invalidZipFile, got \(voxError)")
            }
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testMissingManifest() throws {
        // Create a ZIP without manifest.json
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-manifest-\(UUID().uuidString).vox")

        // Create a simple ZIP with a different file
        try "Some content".write(
            to: FileManager.default.temporaryDirectory.appendingPathComponent("dummy.txt"),
            atomically: true,
            encoding: .utf8
        )

        // Use system zip to create archive without manifest.json
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = [
            "-j", // junk paths
            tempURL.path,
            FileManager.default.temporaryDirectory.appendingPathComponent("dummy.txt").path
        ]
        try process.run()
        process.waitUntilExit()

        let reader = VoxReader()

        XCTAssertThrowsError(
            try reader.read(from: tempURL),
            "Should throw error for missing manifest"
        ) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(error)")
                return
            }
            if case .manifestNotFound = voxError {
                // Expected error
            } else {
                XCTFail("Expected VoxError.manifestNotFound, got \(voxError)")
            }
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("dummy.txt"))
    }

    // MARK: - Helper Methods

    private func assertManifestsEqual(_ lhs: VoxManifest, _ rhs: VoxManifest, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(lhs.voxVersion, rhs.voxVersion, "vox_version mismatch", file: file, line: line)
        XCTAssertEqual(lhs.id, rhs.id, "id mismatch", file: file, line: line)

        // Date comparison with tolerance (JSON encoding may lose precision)
        XCTAssertEqual(
            lhs.created.timeIntervalSince1970,
            rhs.created.timeIntervalSince1970,
            accuracy: 1.0,
            "created timestamp mismatch",
            file: file,
            line: line
        )

        // Voice
        XCTAssertEqual(lhs.voice.name, rhs.voice.name, "voice.name mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.description, rhs.voice.description, "voice.description mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.language, rhs.voice.language, "voice.language mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.gender, rhs.voice.gender, "voice.gender mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.ageRange, rhs.voice.ageRange, "voice.age_range mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.tags, rhs.voice.tags, "voice.tags mismatch", file: file, line: line)

        // Prosody
        XCTAssertEqual(lhs.prosody?.pitchBase, rhs.prosody?.pitchBase, "prosody.pitch_base mismatch", file: file, line: line)
        XCTAssertEqual(lhs.prosody?.pitchRange, rhs.prosody?.pitchRange, "prosody.pitch_range mismatch", file: file, line: line)
        XCTAssertEqual(lhs.prosody?.rate, rhs.prosody?.rate, "prosody.rate mismatch", file: file, line: line)
        XCTAssertEqual(lhs.prosody?.energy, rhs.prosody?.energy, "prosody.energy mismatch", file: file, line: line)
        XCTAssertEqual(lhs.prosody?.emotionDefault, rhs.prosody?.emotionDefault, "prosody.emotion_default mismatch", file: file, line: line)

        // Reference Audio
        XCTAssertEqual(lhs.referenceAudio?.count, rhs.referenceAudio?.count, "reference_audio count mismatch", file: file, line: line)

        // Character
        XCTAssertEqual(lhs.character?.role, rhs.character?.role, "character.role mismatch", file: file, line: line)
        XCTAssertEqual(lhs.character?.emotionalRange, rhs.character?.emotionalRange, "character.emotional_range mismatch", file: file, line: line)
        XCTAssertEqual(lhs.character?.relationships, rhs.character?.relationships, "character.relationships mismatch", file: file, line: line)
        XCTAssertEqual(lhs.character?.source?.work, rhs.character?.source?.work, "character.source.work mismatch", file: file, line: line)

        // Provenance
        XCTAssertEqual(lhs.provenance?.method, rhs.provenance?.method, "provenance.method mismatch", file: file, line: line)
        XCTAssertEqual(lhs.provenance?.engine, rhs.provenance?.engine, "provenance.engine mismatch", file: file, line: line)
        XCTAssertEqual(lhs.provenance?.license, rhs.provenance?.license, "provenance.license mismatch", file: file, line: line)
    }
}
