import XCTest
@testable import VoxFormat

final class RoundtripTests: XCTestCase {

    // MARK: - VOX-044: Roundtrip Integration Tests

    func testRoundtripMinimalVoxFile() throws {
        let originalManifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "RoundtripMinimal",
                description: "A minimal voice for roundtrip testing verification."
            )
        )

        let originalVoxFile = VoxFile(manifest: originalManifest)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-minimal-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try originalVoxFile.write(to: outputURL)
        let readBack = try VoxFile(contentsOf: outputURL)

        XCTAssertEqual(readBack.manifest.voxVersion, VoxFormat.currentVersion)
        XCTAssertEqual(readBack.manifest.id, originalManifest.id)
        XCTAssertEqual(
            readBack.manifest.created.timeIntervalSince1970,
            originalManifest.created.timeIntervalSince1970,
            accuracy: 1.0,
            "Dates should match within 1 second tolerance"
        )
        XCTAssertEqual(readBack.manifest.voice.name, originalManifest.voice.name)
        XCTAssertEqual(readBack.manifest.voice.description, originalManifest.voice.description)
        XCTAssertNil(readBack.manifest.prosody)
        XCTAssertNil(readBack.manifest.referenceAudio)
        XCTAssertNil(readBack.manifest.character)
        XCTAssertNil(readBack.manifest.provenance)
        XCTAssertNil(readBack.manifest.extensions)
        XCTAssertTrue(readBack.entries(under: "reference/").isEmpty)
        XCTAssertTrue(readBack.entries(under: "embeddings/").isEmpty)
    }

    func testRoundtripFullySpecifiedVoxFile() throws {
        let originalManifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-abcd-4efg-8hij-klmnopqrstuv",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "RoundtripFull",
                description: "A fully specified voice for comprehensive roundtrip testing.",
                language: "en-GB",
                gender: "male",
                ageRange: [35, 45],
                tags: ["test", "roundtrip", "comprehensive", "british"]
            ),
            prosody: VoxManifest.Prosody(
                pitchBase: "low",
                pitchRange: "moderate",
                rate: "moderate",
                energy: "medium",
                emotionDefault: "calm authority"
            ),
            character: VoxManifest.Character(
                role: "Test character for roundtrip verification.",
                emotionalRange: ["neutral", "contemplative", "assertive"],
                relationships: [
                    "HERO": "Mentor and guide",
                    "VILLAIN": "Adversary but respected"
                ],
                source: VoxManifest.Source(
                    work: "Roundtrip Test",
                    format: "fountain",
                    file: "test.fountain"
                )
            ),
            provenance: VoxManifest.Provenance(
                method: "designed",
                engine: "test-engine-v1",
                consent: nil,
                license: "CC0-1.0",
                notes: "Created for roundtrip testing purposes"
            )
        )

        let originalVoxFile = VoxFile(manifest: originalManifest)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-full-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try originalVoxFile.write(to: outputURL)
        let readBack = try VoxFile(contentsOf: outputURL)

        XCTAssertEqual(readBack.manifest.voxVersion, VoxFormat.currentVersion)
        XCTAssertEqual(readBack.manifest.id, originalManifest.id)
        XCTAssertEqual(
            readBack.manifest.created.timeIntervalSince1970,
            originalManifest.created.timeIntervalSince1970,
            accuracy: 1.0
        )

        // Voice
        XCTAssertEqual(readBack.manifest.voice.name, originalManifest.voice.name)
        XCTAssertEqual(readBack.manifest.voice.description, originalManifest.voice.description)
        XCTAssertEqual(readBack.manifest.voice.language, originalManifest.voice.language)
        XCTAssertEqual(readBack.manifest.voice.gender, originalManifest.voice.gender)
        XCTAssertEqual(readBack.manifest.voice.ageRange, originalManifest.voice.ageRange)
        XCTAssertEqual(readBack.manifest.voice.tags, originalManifest.voice.tags)

        // Prosody
        XCTAssertNotNil(readBack.manifest.prosody)
        XCTAssertEqual(readBack.manifest.prosody?.pitchBase, originalManifest.prosody?.pitchBase)
        XCTAssertEqual(readBack.manifest.prosody?.pitchRange, originalManifest.prosody?.pitchRange)
        XCTAssertEqual(readBack.manifest.prosody?.rate, originalManifest.prosody?.rate)
        XCTAssertEqual(readBack.manifest.prosody?.energy, originalManifest.prosody?.energy)
        XCTAssertEqual(readBack.manifest.prosody?.emotionDefault, originalManifest.prosody?.emotionDefault)

        // Character
        XCTAssertNotNil(readBack.manifest.character)
        XCTAssertEqual(readBack.manifest.character?.role, originalManifest.character?.role)
        XCTAssertEqual(readBack.manifest.character?.emotionalRange, originalManifest.character?.emotionalRange)
        XCTAssertEqual(readBack.manifest.character?.relationships, originalManifest.character?.relationships)
        XCTAssertEqual(readBack.manifest.character?.source?.work, originalManifest.character?.source?.work)
        XCTAssertEqual(readBack.manifest.character?.source?.format, originalManifest.character?.source?.format)
        XCTAssertEqual(readBack.manifest.character?.source?.file, originalManifest.character?.source?.file)

        // Provenance
        XCTAssertNotNil(readBack.manifest.provenance)
        XCTAssertEqual(readBack.manifest.provenance?.method, originalManifest.provenance?.method)
        XCTAssertEqual(readBack.manifest.provenance?.engine, originalManifest.provenance?.engine)
        XCTAssertNil(readBack.manifest.provenance?.consent)
        XCTAssertEqual(readBack.manifest.provenance?.license, originalManifest.provenance?.license)
        XCTAssertEqual(readBack.manifest.provenance?.notes, originalManifest.provenance?.notes)
    }

    func testRoundtripWithReferenceAudio() throws {
        let audioFileName = "roundtrip-audio-\(UUID().uuidString).wav"
        let audioContent = Data(repeating: 0xAB, count: 1024)

        let voxFile = VoxFile(
            name: "AudioRoundtrip",
            description: "Voice with reference audio for roundtrip testing."
        )
        try voxFile.add(audioContent, at: "reference/\(audioFileName)", metadata: [
            "transcript": "This is a test audio roundtrip.",
            "language": "en-US",
            "duration_seconds": 3.5
        ])

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-audio-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try voxFile.write(to: outputURL)
        let readBack = try VoxFile(contentsOf: outputURL)

        XCTAssertEqual(readBack.manifest.voice.name, "AudioRoundtrip")
        XCTAssertEqual(readBack.manifest.referenceAudio?.count, 1)
        XCTAssertEqual(readBack.manifest.referenceAudio?.first?.transcript, "This is a test audio roundtrip.")
        XCTAssertEqual(readBack.manifest.referenceAudio?.first?.durationSeconds, 3.5)

        let refEntries = readBack.entries(under: "reference/")
        XCTAssertEqual(refEntries.count, 1)
        XCTAssertEqual(refEntries.first?.data.count, audioContent.count, "Audio data size should match")
        XCTAssertEqual(refEntries.first?.data, audioContent, "Audio data content should match exactly")
    }

    func testRoundtripWithEmbeddings() throws {
        let voxFile = VoxFile(
            name: "EmbeddingRoundtrip",
            description: "Voice with embeddings for roundtrip testing."
        )
        let clonePrompt = Data(repeating: 0xCD, count: 512)
        try voxFile.add(clonePrompt, at: "embeddings/qwen3-tts/clone-prompt.bin", metadata: [
            "model": "qwen3-tts"
        ])

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-embed-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try voxFile.write(to: outputURL)
        let readBack = try VoxFile(contentsOf: outputURL)

        let embeddingEntries = readBack.entries(under: "embeddings/")
        XCTAssertEqual(embeddingEntries.count, 1)
        XCTAssertEqual(readBack["embeddings/qwen3-tts/clone-prompt.bin"]?.data, clonePrompt)
    }

    func testRoundtripReadExistingExampleAndRewrite() throws {
        let swiftDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let exampleURL = swiftDir.appendingPathComponent("examples/minimal/narrator.vox")
        guard FileManager.default.fileExists(atPath: exampleURL.path) else {
            XCTFail("Example file narrator.vox not found")
            return
        }

        let original = try VoxFile(contentsOf: exampleURL)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rewrite-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try original.write(to: outputURL)
        let rewritten = try VoxFile(contentsOf: outputURL)

        XCTAssertEqual(rewritten.manifest.voxVersion, original.manifest.voxVersion)
        XCTAssertEqual(rewritten.manifest.id, original.manifest.id)
        XCTAssertEqual(rewritten.manifest.voice.name, original.manifest.voice.name)
        XCTAssertEqual(rewritten.manifest.voice.description, original.manifest.voice.description)
    }

    func testRoundtripWithModelTaggedReferenceAudio() throws {
        let voxFile = VoxFile(
            name: "ModelTaggedAudio",
            description: "Voice with model-tagged reference audio for roundtrip testing."
        )

        let universalAudio = Data(repeating: 0xAA, count: 512)
        try voxFile.add(universalAudio, at: "reference/universal.wav", metadata: [
            "transcript": "Universal clip with no model tag.",
            "language": "en-US"
        ])

        let modelAudio = Data(repeating: 0xBB, count: 512)
        try voxFile.add(modelAudio, at: "reference/qwen3-sample.wav", metadata: [
            "transcript": "Model-tagged clip for Qwen3.",
            "language": "en-US",
            "model": "Qwen/Qwen3-TTS-12Hz-1.7B",
            "engine": "qwen3-tts"
        ])

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-model-tagged-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try voxFile.write(to: outputURL)
        let readBack = try VoxFile(contentsOf: outputURL)

        XCTAssertEqual(readBack.manifest.referenceAudio?.count, 2)

        // Check model-tagged clip survived roundtrip
        let taggedClip = readBack.manifest.referenceAudio?.first { $0.model != nil }
        XCTAssertNotNil(taggedClip)
        XCTAssertEqual(taggedClip?.model, "Qwen/Qwen3-TTS-12Hz-1.7B")
        XCTAssertEqual(taggedClip?.engine, "qwen3-tts")

        // Check universal clip
        let universalClip = readBack.manifest.referenceAudio?.first { $0.model == nil }
        XCTAssertNotNil(universalClip)

        // Test referenceAudio(for:) query
        let qwenClips = readBack.referenceAudio(for: "1.7B")
        XCTAssertEqual(qwenClips.count, 1)
        XCTAssertEqual(qwenClips.first?.model, "Qwen/Qwen3-TTS-12Hz-1.7B")

        // Fallback to universal when no match
        let unknownClips = readBack.referenceAudio(for: "nonexistent-model")
        XCTAssertEqual(unknownClips.count, 1, "Should fall back to universal clips")
        XCTAssertNil(unknownClips.first?.model, "Fallback clips should be universal (no model tag)")
    }

    func testWriteAndSystemUnzipValidation() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: UUID().uuidString,
            created: Date(),
            voice: VoxManifest.Voice(
                name: "SystemValidation",
                description: "Voice created to validate system unzip compatibility."
            ),
            prosody: VoxManifest.Prosody(
                pitchBase: "medium",
                rate: "moderate"
            )
        )

        let voxFile = VoxFile(manifest: manifest)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sysunzip-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try voxFile.write(to: outputURL)

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
            "System unzip -t should validate the created .vox file"
        )

        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        listProcess.arguments = ["-l", outputURL.path]
        let listPipe = Pipe()
        listProcess.standardOutput = listPipe
        listProcess.standardError = listPipe
        try listProcess.run()
        listProcess.waitUntilExit()

        let listOutput = String(
            data: listPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        XCTAssertTrue(
            listOutput.contains("manifest.json"),
            "Archive listing should include manifest.json"
        )
    }
}
