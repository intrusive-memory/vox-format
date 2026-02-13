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

    /// Creates a temporary directory with a manifest.json file containing the given content.
    private func createTempDirWithManifest(_ content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try content.write(to: manifestURL, atomically: true, encoding: .utf8)

        return tempDir
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

    // MARK: - VOX-036: ZIP Extraction Tests

    func testExtractValidVoxFile() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "Example file narrator.vox should exist at \(url.path)"
        )

        let extractedDir = try reader.extractArchive(at: url)
        defer { try? FileManager.default.removeItem(at: extractedDir) }

        // Verify extraction produced a manifest.json
        let manifestPath = extractedDir.appendingPathComponent("manifest.json").path
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: manifestPath),
            "Extracted archive should contain manifest.json"
        )
    }

    func testExtractNonZipFileThrowsInvalidZipFile() throws {
        // Create a temporary text file (not a ZIP)
        let tempDir = FileManager.default.temporaryDirectory
        let fakeVox = tempDir.appendingPathComponent("fake-\(UUID().uuidString).vox")
        let content = "This is not a ZIP file".data(using: .utf8)!
        FileManager.default.createFile(atPath: fakeVox.path, contents: content)
        defer { try? FileManager.default.removeItem(at: fakeVox) }

        do {
            let extracted = try reader.extractArchive(at: fakeVox)
            try? FileManager.default.removeItem(at: extracted)
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

    func testExtractCleansTempOnError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fakeVox = tempDir.appendingPathComponent("cleanup-test-\(UUID().uuidString).vox")
        let content = "Not a ZIP".data(using: .utf8)!
        FileManager.default.createFile(atPath: fakeVox.path, contents: content)
        defer { try? FileManager.default.removeItem(at: fakeVox) }

        // Count vox- dirs before
        let tempContents = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        )
        let voxDirsBefore = tempContents.filter {
            $0.lastPathComponent.hasPrefix("vox-")
        }.count

        // Attempt extraction (should fail)
        _ = try? reader.extractArchive(at: fakeVox)

        // Count vox- dirs after
        let tempContentsAfter = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        )
        let voxDirsAfter = tempContentsAfter.filter {
            $0.lastPathComponent.hasPrefix("vox-")
        }.count

        XCTAssertEqual(
            voxDirsBefore, voxDirsAfter,
            "Temp directories should be cleaned up on extraction failure"
        )
    }

    // MARK: - VOX-037: Manifest Parsing Tests

    func testParseMinimalManifest() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        let extractedDir = try reader.extractArchive(at: url)
        defer { try? FileManager.default.removeItem(at: extractedDir) }

        let manifest = try reader.parseManifest(in: extractedDir, archiveURL: url)

        XCTAssertEqual(manifest.voxVersion, "0.1.0")
        XCTAssertEqual(manifest.id, "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78")
        XCTAssertEqual(manifest.voice.name, "Narrator")
        XCTAssertNil(manifest.prosody)
        XCTAssertNil(manifest.referenceAudio)
    }

    func testParseCharacterManifestWithContext() throws {
        let url = exampleURL("examples/character/narrator-with-context.vox")
        let extractedDir = try reader.extractArchive(at: url)
        defer { try? FileManager.default.removeItem(at: extractedDir) }

        let manifest = try reader.parseManifest(in: extractedDir, archiveURL: url)

        XCTAssertEqual(manifest.voxVersion, "0.1.0")
        XCTAssertEqual(manifest.voice.name, "NARRATOR")
        XCTAssertEqual(manifest.voice.language, "en-GB")
        XCTAssertNotNil(manifest.prosody)
        XCTAssertNotNil(manifest.character)
        XCTAssertEqual(manifest.character?.emotionalRange?.count, 5)
        XCTAssertNotNil(manifest.provenance)
        XCTAssertEqual(manifest.provenance?.method, "designed")
    }

    func testParseMultiEngineManifest() throws {
        let url = exampleURL("examples/multi-engine/cross-platform.vox")
        let extractedDir = try reader.extractArchive(at: url)
        defer { try? FileManager.default.removeItem(at: extractedDir) }

        let manifest = try reader.parseManifest(in: extractedDir, archiveURL: url)

        XCTAssertEqual(manifest.voice.name, "VERSATILE")
        XCTAssertNotNil(manifest.extensions)
        XCTAssertEqual(manifest.extensions?.keys.count, 3)
        XCTAssertTrue(manifest.extensions?.keys.contains("apple") ?? false)
        XCTAssertTrue(manifest.extensions?.keys.contains("elevenlabs") ?? false)
        XCTAssertTrue(manifest.extensions?.keys.contains("qwen3-tts") ?? false)
    }

    func testParseMissingManifestThrowsError() throws {
        // Create a ZIP that contains a dummy file, not manifest.json
        let zipURL = try createZipWithFile(named: "dummy.txt", content: "This is not a manifest")
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let extractedDir = try reader.extractArchive(at: zipURL)
        defer { try? FileManager.default.removeItem(at: extractedDir) }

        do {
            _ = try reader.parseManifest(in: extractedDir, archiveURL: zipURL)
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

    func testParseInvalidJSONManifestThrowsError() throws {
        // Create a ZIP with invalid JSON as manifest.json
        let zipURL = try createZipWithFile(
            named: "manifest.json",
            content: "{ this is not valid json }"
        )
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let extractedDir = try reader.extractArchive(at: zipURL)
        defer { try? FileManager.default.removeItem(at: extractedDir) }

        do {
            _ = try reader.parseManifest(in: extractedDir, archiveURL: zipURL)
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

    func testParseMissingManifestFromDirectory() throws {
        // Test parseManifest directly with a directory that has no manifest.json
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-manifest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dummyURL = URL(fileURLWithPath: "/fake/path.vox")

        do {
            _ = try reader.parseManifest(in: tempDir, archiveURL: dummyURL)
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

    func testParseInvalidJSONFromDirectory() throws {
        // Test parseManifest with a directory containing bad JSON
        let tempDir = try createTempDirWithManifest("{ broken json !!!")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dummyURL = URL(fileURLWithPath: "/fake/path.vox")

        do {
            _ = try reader.parseManifest(in: tempDir, archiveURL: dummyURL)
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

    // MARK: - VOX-038: Reference Audio Enumeration Tests

    func testEnumerateReferenceAudioWithNoAudio() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        let extractedDir = try reader.extractArchive(at: url)
        defer { try? FileManager.default.removeItem(at: extractedDir) }

        let manifest = try reader.parseManifest(in: extractedDir, archiveURL: url)
        let audioURLs = reader.enumerateReferenceAudio(in: extractedDir, manifest: manifest)

        XCTAssertTrue(audioURLs.isEmpty, "Minimal manifest has no reference audio")
    }

    func testEnumerateReferenceAudioWithMissingDirectory() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "test-id",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "Test voice for enumeration testing."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/test.wav",
                    transcript: "Test transcript"
                )
            ]
        )

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let audioURLs = reader.enumerateReferenceAudio(in: tempDir, manifest: manifest)
        XCTAssertTrue(audioURLs.isEmpty)
    }

    func testEnumerateReferenceAudioWithExistingFiles() throws {
        // Create a directory with a reference/ subdirectory and an audio file
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-enum-\(UUID().uuidString)")
        let referenceDir = tempDir.appendingPathComponent("reference")
        try FileManager.default.createDirectory(at: referenceDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a dummy audio file
        let audioFile = referenceDir.appendingPathComponent("sample.wav")
        let audioData = Data(repeating: 0xFF, count: 100)
        FileManager.default.createFile(atPath: audioFile.path, contents: audioData)

        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "test-id",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "Test voice with existing reference audio."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/sample.wav",
                    transcript: "Sample audio transcript"
                )
            ]
        )

        let audioURLs = reader.enumerateReferenceAudio(in: tempDir, manifest: manifest)
        XCTAssertEqual(audioURLs.count, 1)
        XCTAssertEqual(audioURLs.first?.lastPathComponent, "sample.wav")
    }

    // MARK: - VOX-040: Complete VoxReader Tests

    func testReadMinimalVox() throws {
        let url = exampleURL("examples/minimal/narrator.vox")
        let voxFile = try reader.read(from: url)

        XCTAssertEqual(voxFile.manifest.voxVersion, "0.1.0")
        XCTAssertEqual(voxFile.manifest.voice.name, "Narrator")
        XCTAssertTrue(voxFile.referenceAudioURLs.isEmpty)
        XCTAssertNil(voxFile.extensionsDirectory)
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
