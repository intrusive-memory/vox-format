import XCTest
@testable import VoxFormat
import Foundation

/// Integration tests using real .vox files from examples directory
final class IntegrationTests: XCTestCase {

    // MARK: - Test Resources

    private var examplesPath: URL {
        let currentFile = URL(fileURLWithPath: #filePath)
        let testsDir = currentFile.deletingLastPathComponent().deletingLastPathComponent()
        let swiftDir = testsDir.deletingLastPathComponent()
        let implementationsDir = swiftDir.deletingLastPathComponent()
        let projectRoot = implementationsDir.deletingLastPathComponent()
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

        for example in exampleFiles {
            let voxURL = exampleVoxURL(path: example.path)

            XCTAssertTrue(
                FileManager.default.fileExists(atPath: voxURL.path),
                "Example file not found: \(example.path)"
            )

            let voxFile = try VoxFile(contentsOf: voxURL)

            XCTAssertEqual(
                voxFile.manifest.voice.name,
                example.expectedName,
                "Unexpected voice name in \(example.path)"
            )

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

        for examplePath in exampleFiles {
            let voxURL = exampleVoxURL(path: examplePath)
            let voxFile = try VoxFile(contentsOf: voxURL)

            let errors = voxFile.validate().filter { $0.severity == .error }
            XCTAssertTrue(errors.isEmpty, "Validation failed for \(examplePath)")
        }
    }

    // MARK: - Roundtrip Tests

    func testRoundtripMinimal() throws {
        let originalURL = exampleVoxURL(path: "minimal/narrator.vox")
        let originalVoxFile = try VoxFile(contentsOf: originalURL)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-minimal-\(UUID().uuidString).vox")
        try originalVoxFile.write(to: tempURL)

        let roundtripVoxFile = try VoxFile(contentsOf: tempURL)
        assertManifestsEqual(originalVoxFile.manifest, roundtripVoxFile.manifest)

        try? FileManager.default.removeItem(at: tempURL)
    }

    func testRoundtripCharacter() throws {
        let originalURL = exampleVoxURL(path: "character/narrator-with-context.vox")
        let originalVoxFile = try VoxFile(contentsOf: originalURL)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-character-\(UUID().uuidString).vox")
        try originalVoxFile.write(to: tempURL)

        let roundtripVoxFile = try VoxFile(contentsOf: tempURL)
        assertManifestsEqual(originalVoxFile.manifest, roundtripVoxFile.manifest)

        try? FileManager.default.removeItem(at: tempURL)
    }

    func testRoundtripContext() throws {
        let originalURL = exampleVoxURL(path: "character/narrator-with-context.vox")
        let originalVoxFile = try VoxFile(contentsOf: originalURL)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-context-\(UUID().uuidString).vox")
        try originalVoxFile.write(to: tempURL)

        let roundtripVoxFile = try VoxFile(contentsOf: tempURL)

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

        try? FileManager.default.removeItem(at: tempURL)
    }

    func testRoundtripMultiEngine() throws {
        let originalURL = exampleVoxURL(path: "multi-engine/cross-platform.vox")
        let originalVoxFile = try VoxFile(contentsOf: originalURL)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-multiengine-\(UUID().uuidString).vox")
        try originalVoxFile.write(to: tempURL)

        let roundtripVoxFile = try VoxFile(contentsOf: tempURL)

        XCTAssertEqual(
            originalVoxFile.manifest.extensions?.keys.sorted(),
            roundtripVoxFile.manifest.extensions?.keys.sorted()
        )

        assertManifestsEqual(originalVoxFile.manifest, roundtripVoxFile.manifest)

        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Error Handling Tests

    func testInvalidManifest() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Invalid",
                description: ""
            )
        )
        let vox = VoxFile(manifest: manifest)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid-manifest-\(UUID().uuidString).vox")
        try vox.write(to: tempURL)

        let readBack = try VoxFile(contentsOf: tempURL)
        let errors = readBack.validate().filter { $0.severity == .error }
        XCTAssertFalse(errors.isEmpty, "Should have validation errors for empty description")

        try? FileManager.default.removeItem(at: tempURL)
    }

    func testInvalidZip() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-zip-\(UUID().uuidString).vox")

        try "This is not a ZIP file".write(to: tempURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try VoxFile(contentsOf: tempURL),
            "Should throw error for invalid ZIP"
        ) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(error)")
                return
            }
            if case .invalidZipFile = voxError {
                // Expected
            } else {
                XCTFail("Expected VoxError.invalidZipFile, got \(voxError)")
            }
        }

        try? FileManager.default.removeItem(at: tempURL)
    }

    func testMissingManifest() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-manifest-\(UUID().uuidString).vox")

        try "Some content".write(
            to: FileManager.default.temporaryDirectory.appendingPathComponent("dummy.txt"),
            atomically: true,
            encoding: .utf8
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = [
            "-j",
            tempURL.path,
            FileManager.default.temporaryDirectory.appendingPathComponent("dummy.txt").path
        ]
        try process.run()
        process.waitUntilExit()

        XCTAssertThrowsError(
            try VoxFile(contentsOf: tempURL),
            "Should throw error for missing manifest"
        ) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(error)")
                return
            }
            if case .manifestNotFound = voxError {
                // Expected
            } else {
                XCTFail("Expected VoxError.manifestNotFound, got \(voxError)")
            }
        }

        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("dummy.txt"))
    }

    // MARK: - Helper Methods

    private func assertManifestsEqual(_ lhs: VoxManifest, _ rhs: VoxManifest, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(lhs.voxVersion, rhs.voxVersion, "vox_version mismatch", file: file, line: line)
        XCTAssertEqual(lhs.id, rhs.id, "id mismatch", file: file, line: line)
        XCTAssertEqual(
            lhs.created.timeIntervalSince1970,
            rhs.created.timeIntervalSince1970,
            accuracy: 1.0,
            "created timestamp mismatch",
            file: file,
            line: line
        )
        XCTAssertEqual(lhs.voice.name, rhs.voice.name, "voice.name mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.description, rhs.voice.description, "voice.description mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.language, rhs.voice.language, "voice.language mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.gender, rhs.voice.gender, "voice.gender mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.ageRange, rhs.voice.ageRange, "voice.age_range mismatch", file: file, line: line)
        XCTAssertEqual(lhs.voice.tags, rhs.voice.tags, "voice.tags mismatch", file: file, line: line)
        XCTAssertEqual(lhs.prosody?.pitchBase, rhs.prosody?.pitchBase, "prosody.pitch_base mismatch", file: file, line: line)
        XCTAssertEqual(lhs.prosody?.pitchRange, rhs.prosody?.pitchRange, "prosody.pitch_range mismatch", file: file, line: line)
        XCTAssertEqual(lhs.prosody?.rate, rhs.prosody?.rate, "prosody.rate mismatch", file: file, line: line)
        XCTAssertEqual(lhs.prosody?.energy, rhs.prosody?.energy, "prosody.energy mismatch", file: file, line: line)
        XCTAssertEqual(lhs.prosody?.emotionDefault, rhs.prosody?.emotionDefault, "prosody.emotion_default mismatch", file: file, line: line)
        XCTAssertEqual(lhs.referenceAudio?.count, rhs.referenceAudio?.count, "reference_audio count mismatch", file: file, line: line)
        XCTAssertEqual(lhs.character?.role, rhs.character?.role, "character.role mismatch", file: file, line: line)
        XCTAssertEqual(lhs.character?.emotionalRange, rhs.character?.emotionalRange, "character.emotional_range mismatch", file: file, line: line)
        XCTAssertEqual(lhs.character?.relationships, rhs.character?.relationships, "character.relationships mismatch", file: file, line: line)
        XCTAssertEqual(lhs.character?.source?.work, rhs.character?.source?.work, "character.source.work mismatch", file: file, line: line)
        XCTAssertEqual(lhs.provenance?.method, rhs.provenance?.method, "provenance.method mismatch", file: file, line: line)
        XCTAssertEqual(lhs.provenance?.engine, rhs.provenance?.engine, "provenance.engine mismatch", file: file, line: line)
        XCTAssertEqual(lhs.provenance?.license, rhs.provenance?.license, "provenance.license mismatch", file: file, line: line)
    }
}
