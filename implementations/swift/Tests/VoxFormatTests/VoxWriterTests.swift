import XCTest
@testable import VoxFormat

final class VoxWriterTests: XCTestCase {

    let writer = VoxWriter()
    let reader = VoxReader()

    // MARK: - VOX-042: Manifest JSON Writing Tests

    func testEncodeManifestProducesValidJSON() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice for JSON encoding verification."
            )
        )

        let data = try writer.encodeManifest(manifest)

        // Verify it's valid JSON
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(jsonObject is [String: Any], "Encoded data should be a JSON object")

        // Verify it's pretty-printed (contains newlines)
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("\n"), "JSON should be pretty-printed")

        // Verify snake_case keys
        XCTAssertTrue(jsonString.contains("vox_version"))
        XCTAssertFalse(jsonString.contains("voxVersion"))
    }

    func testEncodeManifestWithAllFields() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "FullVoice",
                description: "A fully specified voice for comprehensive encoding test.",
                language: "en-US",
                gender: "neutral",
                ageRange: [25, 35],
                tags: ["test", "comprehensive"]
            ),
            prosody: VoxManifest.Prosody(
                pitchBase: "medium",
                pitchRange: "wide",
                rate: "moderate",
                energy: "high",
                emotionDefault: "enthusiastic"
            ),
            provenance: VoxManifest.Provenance(
                method: "designed",
                engine: "test-engine",
                consent: nil,
                license: "CC0-1.0"
            )
        )

        let data = try writer.encodeManifest(manifest)

        // Decode back and verify
        let decoder = VoxManifest.decoder()
        let decoded = try decoder.decode(VoxManifest.self, from: data)

        XCTAssertEqual(decoded.voxVersion, "0.1.0")
        XCTAssertEqual(decoded.voice.name, "FullVoice")
        XCTAssertEqual(decoded.voice.language, "en-US")
        XCTAssertEqual(decoded.prosody?.pitchBase, "medium")
        XCTAssertEqual(decoded.provenance?.method, "designed")
    }

    // MARK: - VOX-043: ZIP Archive Creation Tests

    func testWriteMinimalVoxFile() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: UUID().uuidString,
            created: Date(),
            voice: VoxManifest.Voice(
                name: "WriterTest",
                description: "A test voice created by VoxWriter test suite."
            )
        )

        let voxFile = VoxFile(manifest: manifest)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("writer-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(voxFile, to: outputURL)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify ZIP magic bytes
        let handle = try FileHandle(forReadingFrom: outputURL)
        let magicData = handle.readData(ofLength: 4)
        handle.closeFile()
        XCTAssertEqual(Array(magicData), [0x50, 0x4B, 0x03, 0x04], "Should have PK magic bytes")
    }

    func testWriteVoxFileCanBeUnzippedBySystem() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: UUID().uuidString,
            created: Date(),
            voice: VoxManifest.Voice(
                name: "UnzipTest",
                description: "A test voice to verify system unzip compatibility."
            )
        )

        let voxFile = VoxFile(manifest: manifest)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("unzip-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(voxFile, to: outputURL)

        // Verify with system unzip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", outputURL.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(
            process.terminationStatus, 0,
            "System unzip -t should succeed on written .vox file"
        )
    }

    func testWriteVoxFileWithReferenceAudio() throws {
        let audioContent = "RIFF\0\0\0\0WAVEfmt ".data(using: .ascii)!
        let audioFileName = "test-audio-\(UUID().uuidString).wav"

        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: UUID().uuidString,
            created: Date(),
            voice: VoxManifest.Voice(
                name: "AudioTest",
                description: "A test voice with reference audio for archive creation."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/\(audioFileName)",
                    transcript: "Test audio transcript.",
                    language: "en-US",
                    durationSeconds: 3.0
                )
            ]
        )

        let voxFile = VoxFile(
            manifest: manifest,
            referenceAudio: [audioFileName: audioContent]
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(voxFile, to: outputURL)

        // Verify archive contains both manifest.json and the reference audio
        let readBack = try reader.read(from: outputURL)
        XCTAssertEqual(readBack.manifest.voice.name, "AudioTest")
        XCTAssertEqual(readBack.manifest.referenceAudio?.count, 1)
        XCTAssertEqual(readBack.referenceAudio.count, 1)
        XCTAssertEqual(readBack.referenceAudio[audioFileName], audioContent)
    }

    func testWriteVoxFileWithEmbeddings() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: UUID().uuidString,
            created: Date(),
            voice: VoxManifest.Voice(
                name: "EmbeddingTest",
                description: "A test voice with embeddings for archive creation."
            )
        )

        let embeddingData = Data(repeating: 0xAB, count: 256)
        let voxFile = VoxFile(
            manifest: manifest,
            embeddings: ["qwen3-tts/clone-prompt.bin": embeddingData]
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("embedding-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(voxFile, to: outputURL)

        let readBack = try reader.read(from: outputURL)
        XCTAssertEqual(readBack.embeddings["qwen3-tts/clone-prompt.bin"], embeddingData)
    }

    func testWriteOverwritesExistingFile() throws {
        let manifest1 = VoxManifest(
            voxVersion: "0.1.0",
            id: UUID().uuidString,
            created: Date(),
            voice: VoxManifest.Voice(
                name: "First",
                description: "First version of the voice file."
            )
        )

        let manifest2 = VoxManifest(
            voxVersion: "0.1.0",
            id: UUID().uuidString,
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Second",
                description: "Second version, should replace the first."
            )
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("overwrite-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        // Write first
        try writer.write(VoxFile(manifest: manifest1), to: outputURL)

        // Write second (should overwrite)
        try writer.write(VoxFile(manifest: manifest2), to: outputURL)

        // Read back and verify it's the second version
        let readBack = try reader.read(from: outputURL)
        XCTAssertEqual(readBack.manifest.voice.name, "Second")
    }

    func testVerifyZipMagicBytes() throws {
        // Create a valid .vox
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: UUID().uuidString,
            created: Date(),
            voice: VoxManifest.Voice(
                name: "Magic",
                description: "Testing magic byte verification."
            )
        )
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("magic-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(VoxFile(manifest: manifest), to: outputURL)

        // Verify should not throw
        XCTAssertNoThrow(try writer.verifyZipMagicBytes(at: outputURL))
    }

    func testVerifyZipMagicBytesFailsForNonZip() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let notZip = tempDir.appendingPathComponent("not-zip-\(UUID().uuidString).vox")
        let content = "This is not a ZIP".data(using: .utf8)!
        FileManager.default.createFile(atPath: notZip.path, contents: content)
        defer { try? FileManager.default.removeItem(at: notZip) }

        XCTAssertThrowsError(try writer.verifyZipMagicBytes(at: notZip))
    }
}
