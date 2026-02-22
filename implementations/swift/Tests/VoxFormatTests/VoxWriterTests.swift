import XCTest
@testable import VoxFormat

final class VoxWriterTests: XCTestCase {

    // MARK: - ZIP Archive Creation Tests

    func testWriteMinimalVoxFile() throws {
        let vox = VoxFile(name: "WriterTest", description: "A test voice created by VoxWriter test suite.")

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("writer-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try vox.write(to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let handle = try FileHandle(forReadingFrom: outputURL)
        let magicData = handle.readData(ofLength: 4)
        handle.closeFile()
        XCTAssertEqual(Array(magicData), [0x50, 0x4B, 0x03, 0x04], "Should have PK magic bytes")
    }

    func testWriteVoxFileCanBeUnzippedBySystem() throws {
        let vox = VoxFile(name: "UnzipTest", description: "A test voice to verify system unzip compatibility.")

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("unzip-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try vox.write(to: outputURL)

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

        let vox = VoxFile(name: "AudioTest", description: "A test voice with reference audio for archive creation.")
        try vox.add(audioContent, at: "reference/\(audioFileName)", metadata: [
            "transcript": "Test audio transcript.",
            "language": "en-US",
            "duration_seconds": 3.0
        ])

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try vox.write(to: outputURL)

        let readBack = try VoxFile(contentsOf: outputURL)
        XCTAssertEqual(readBack.manifest.voice.name, "AudioTest")
        XCTAssertEqual(readBack.manifest.referenceAudio?.count, 1)
        let refEntries = readBack.entries(under: "reference/")
        XCTAssertEqual(refEntries.count, 1)
        XCTAssertEqual(refEntries.first?.data, audioContent)
    }

    func testWriteVoxFileWithEmbeddings() throws {
        let vox = VoxFile(name: "EmbeddingTest", description: "A test voice with embeddings for archive creation.")
        let embeddingData = Data(repeating: 0xAB, count: 256)
        try vox.add(embeddingData, at: "embeddings/qwen3-tts/clone-prompt.bin", metadata: [
            "model": "qwen3-tts"
        ])

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("embedding-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try vox.write(to: outputURL)

        let readBack = try VoxFile(contentsOf: outputURL)
        let entry = readBack["embeddings/qwen3-tts/clone-prompt.bin"]
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.data, embeddingData)
    }

    func testWriteOverwritesExistingFile() throws {
        let vox1 = VoxFile(name: "First", description: "First version of the voice file.")
        let vox2 = VoxFile(name: "Second", description: "Second version, should replace the first.")

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("overwrite-test-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try vox1.write(to: outputURL)
        try vox2.write(to: outputURL)

        let readBack = try VoxFile(contentsOf: outputURL)
        XCTAssertEqual(readBack.manifest.voice.name, "Second")
    }

    func testManifestEncodesAsValidJSON() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice for JSON encoding verification."
            )
        )

        let data = try VoxManifest.encoder().encode(manifest)

        let jsonObject = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(jsonObject is [String: Any], "Encoded data should be a JSON object")

        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("\n"), "JSON should be pretty-printed")
        XCTAssertTrue(jsonString.contains("vox_version"))
        XCTAssertFalse(jsonString.contains("voxVersion"))
    }
}
