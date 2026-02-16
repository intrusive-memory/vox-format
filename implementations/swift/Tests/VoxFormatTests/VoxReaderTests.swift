import XCTest
@testable import VoxFormat

final class VoxReaderTests: XCTestCase {

    let reader = VoxReader()

    // MARK: - Helper: Locate example files

    /// Returns the URL for an example .vox file relative to the repository root.
    private func exampleURL(_ relativePath: String) -> URL {
        let swiftDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/VoxFormatTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // swift/
            .deletingLastPathComponent() // implementations/
            .deletingLastPathComponent() // vox-format/

        return swiftDir.appendingPathComponent(relativePath)
    }

    /// Creates a ZIP archive containing a single file using the system zip command.
    private func createZipWithFile(
        named fileName: String,
        content: String
    ) throws -> URL {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("zipwork-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        // Write the file
        let fileURL = workDir.appendingPathComponent(fileName)

        // Create parent directories if needed
        let parentDir = fileURL.deletingLastPathComponent()
        if parentDir.path != workDir.path {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Create ZIP using system command
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).vox")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-j", zipURL.path, fileURL.path]
        process.currentDirectoryURL = workDir
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        // Clean up work dir
        try? FileManager.default.removeItem(at: workDir)

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "TestHelper",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to create test ZIP"]
            )
        }

        return zipURL
    }

    // MARK: - VOX-036: ZIP Reading Tests

    func testReadValidVoxFile() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "Example file narrator.vox should exist at \(url.path)"
        )

        let voxFile = try reader.read(from: url)
        XCTAssertEqual(voxFile.manifest.voxVersion, "0.1.0")
        XCTAssertEqual(voxFile.manifest.voice.name, "Narrator")
    }

    func testReadNonZipFileThrowsInvalidZipFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fakeVox = tempDir.appendingPathComponent("fake-\(UUID().uuidString).vox")
        let content = "This is not a ZIP file".data(using: .utf8)!
        FileManager.default.createFile(atPath: fakeVox.path, contents: content)
        defer { try? FileManager.default.removeItem(at: fakeVox) }

        do {
            _ = try reader.read(from: fakeVox)
            XCTFail("Expected VoxError.invalidZipFile to be thrown")
        } catch let error as VoxError {
            switch error {
            case .invalidZipFile:
                break // Expected
            default:
                XCTFail("Expected VoxError.invalidZipFile, got \(error)")
            }
        }
    }

    // MARK: - VOX-037: Manifest Parsing Tests

    func testReadMinimalManifest() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        let voxFile = try reader.read(from: url)

        XCTAssertEqual(voxFile.manifest.voxVersion, "0.1.0")
        XCTAssertEqual(voxFile.manifest.id, "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78")
        XCTAssertEqual(voxFile.manifest.voice.name, "Narrator")
        XCTAssertNil(voxFile.manifest.prosody)
        XCTAssertNil(voxFile.manifest.referenceAudio)
    }

    func testReadCharacterManifestWithContext() throws {
        let url = exampleURL("examples/character/narrator-with-context.vox")
        let voxFile = try reader.read(from: url)

        XCTAssertEqual(voxFile.manifest.voxVersion, "0.1.0")
        XCTAssertEqual(voxFile.manifest.voice.name, "NARRATOR")
        XCTAssertEqual(voxFile.manifest.voice.language, "en-GB")
        XCTAssertNotNil(voxFile.manifest.prosody)
        XCTAssertNotNil(voxFile.manifest.character)
        XCTAssertEqual(voxFile.manifest.character?.emotionalRange?.count, 5)
        XCTAssertNotNil(voxFile.manifest.provenance)
        XCTAssertEqual(voxFile.manifest.provenance?.method, "designed")
    }

    func testReadMultiEngineManifest() throws {
        let url = exampleURL("examples/multi-engine/cross-platform.vox")
        let voxFile = try reader.read(from: url)

        XCTAssertEqual(voxFile.manifest.voice.name, "VERSATILE")
        XCTAssertNotNil(voxFile.manifest.extensions)
        XCTAssertEqual(voxFile.manifest.extensions?.keys.count, 3)
        XCTAssertTrue(voxFile.manifest.extensions?.keys.contains("apple") ?? false)
        XCTAssertTrue(voxFile.manifest.extensions?.keys.contains("elevenlabs") ?? false)
        XCTAssertTrue(voxFile.manifest.extensions?.keys.contains("qwen3-tts") ?? false)
    }

    func testReadMissingManifestThrowsError() throws {
        let zipURL = try createZipWithFile(named: "dummy.txt", content: "This is not a manifest")
        defer { try? FileManager.default.removeItem(at: zipURL) }

        do {
            _ = try reader.read(from: zipURL)
            XCTFail("Expected VoxError.manifestNotFound to be thrown")
        } catch let error as VoxError {
            switch error {
            case .manifestNotFound:
                break // Expected
            default:
                XCTFail("Expected VoxError.manifestNotFound, got \(error)")
            }
        }
    }

    func testReadInvalidJSONManifestThrowsError() throws {
        let zipURL = try createZipWithFile(
            named: "manifest.json",
            content: "{ this is not valid json }"
        )
        defer { try? FileManager.default.removeItem(at: zipURL) }

        do {
            _ = try reader.read(from: zipURL)
            XCTFail("Expected VoxError.invalidJSON to be thrown")
        } catch let error as VoxError {
            switch error {
            case .invalidJSON:
                break // Expected
            default:
                XCTFail("Expected VoxError.invalidJSON, got \(error)")
            }
        }
    }

    // MARK: - VOX-038: Reference Audio Tests

    func testReadMinimalVoxHasNoReferenceAudio() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        let voxFile = try reader.read(from: url)

        XCTAssertTrue(voxFile.referenceAudio.isEmpty, "Minimal manifest has no reference audio")
    }

    // MARK: - VOX-040: Complete VoxReader Tests

    func testReadMinimalVox() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        let voxFile = try reader.read(from: url)

        XCTAssertEqual(voxFile.manifest.voxVersion, "0.1.0")
        XCTAssertEqual(voxFile.manifest.voice.name, "Narrator")
        XCTAssertTrue(voxFile.referenceAudio.isEmpty)
        XCTAssertTrue(voxFile.embeddings.isEmpty)
    }

    func testReadCharacterWithContextVox() throws {
        let url = exampleURL("examples/character/narrator-with-context.vox")
        let voxFile = try reader.read(from: url)

        XCTAssertEqual(voxFile.manifest.voxVersion, "0.1.0")
        XCTAssertEqual(voxFile.manifest.voice.name, "NARRATOR")
        XCTAssertEqual(voxFile.manifest.voice.language, "en-GB")
        XCTAssertNotNil(voxFile.manifest.character)
        XCTAssertNotNil(voxFile.manifest.provenance)
    }

    func testReadMultiEngineVox() throws {
        let url = exampleURL("examples/multi-engine/cross-platform.vox")
        let voxFile = try reader.read(from: url)

        XCTAssertEqual(voxFile.manifest.voice.name, "VERSATILE")
        XCTAssertNotNil(voxFile.manifest.extensions)
        XCTAssertEqual(voxFile.manifest.extensions?.keys.count, 3)
    }

    func testReadNonZipThrowsError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fakeVox = tempDir.appendingPathComponent("read-fail-\(UUID().uuidString).vox")
        let content = "Not a ZIP file at all".data(using: .utf8)!
        FileManager.default.createFile(atPath: fakeVox.path, contents: content)
        defer { try? FileManager.default.removeItem(at: fakeVox) }

        XCTAssertThrowsError(try reader.read(from: fakeVox)) { error in
            guard let voxError = error as? VoxError else {
                XCTFail("Expected VoxError, got \(type(of: error))")
                return
            }
            switch voxError {
            case .invalidZipFile:
                break // Expected
            default:
                XCTFail("Expected VoxError.invalidZipFile, got \(voxError)")
            }
        }
    }

    func testReadAllExampleVoxFiles() throws {
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
            XCTAssertEqual(voxFile.manifest.voxVersion, "0.1.0", "Version mismatch in \(example)")
            XCTAssertFalse(
                voxFile.manifest.voice.name.isEmpty,
                "Voice name should not be empty in \(example)"
            )
        }
    }
}
