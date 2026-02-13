import XCTest
@testable import VoxFormat

final class RoundtripTests: XCTestCase {

    let reader = VoxReader()
    let writer = VoxWriter()

    // MARK: - VOX-044: Roundtrip Integration Tests

    func testRoundtripMinimalVoxFile() throws {
        // Create a minimal VoxFile programmatically
        let originalManifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
            created: Date(timeIntervalSince1970: 1707825600), // 2024-02-13T12:00:00Z
            voice: VoxManifest.Voice(
                name: "RoundtripMinimal",
                description: "A minimal voice for roundtrip testing verification."
            )
        )

        let originalVoxFile = VoxFile(manifest: originalManifest)

        // Write to a temporary .vox file
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-minimal-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(originalVoxFile, to: outputURL)

        // Read it back
        let readBack = try reader.read(from: outputURL)

        // Compare all fields
        XCTAssertEqual(readBack.manifest.voxVersion, originalManifest.voxVersion)
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
        XCTAssertTrue(readBack.referenceAudioURLs.isEmpty)
        XCTAssertNil(readBack.extensionsDirectory)
    }

    func testRoundtripFullySpecifiedVoxFile() throws {
        // Create a fully specified VoxFile
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

        // Write and read back
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-full-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(originalVoxFile, to: outputURL)
        let readBack = try reader.read(from: outputURL)

        // Compare all fields in detail
        XCTAssertEqual(readBack.manifest.voxVersion, originalManifest.voxVersion)
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
        XCTAssertNil(readBack.manifest.provenance?.consent) // Was nil
        XCTAssertEqual(readBack.manifest.provenance?.license, originalManifest.provenance?.license)
        XCTAssertEqual(readBack.manifest.provenance?.notes, originalManifest.provenance?.notes)
    }

    func testRoundtripWithReferenceAudio() throws {
        // Create a temporary audio file
        let tempDir = FileManager.default.temporaryDirectory
        let audioFileName = "roundtrip-audio-\(UUID().uuidString).wav"
        let audioFile = tempDir.appendingPathComponent(audioFileName)
        let audioContent = Data(repeating: 0xAB, count: 1024) // 1KB dummy audio
        FileManager.default.createFile(atPath: audioFile.path, contents: audioContent)
        defer { try? FileManager.default.removeItem(at: audioFile) }

        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: UUID().uuidString,
            created: Date(),
            voice: VoxManifest.Voice(
                name: "AudioRoundtrip",
                description: "Voice with reference audio for roundtrip testing."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/\(audioFileName)",
                    transcript: "This is a test audio roundtrip.",
                    language: "en-US",
                    durationSeconds: 3.5
                )
            ]
        )

        let voxFile = VoxFile(
            manifest: manifest,
            referenceAudioURLs: [audioFile]
        )

        let outputURL = tempDir.appendingPathComponent("roundtrip-audio-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(voxFile, to: outputURL)
        let readBack = try reader.read(from: outputURL)

        // Manifest should match
        XCTAssertEqual(readBack.manifest.voice.name, "AudioRoundtrip")
        XCTAssertEqual(readBack.manifest.referenceAudio?.count, 1)
        XCTAssertEqual(readBack.manifest.referenceAudio?.first?.transcript, "This is a test audio roundtrip.")
        XCTAssertEqual(readBack.manifest.referenceAudio?.first?.durationSeconds, 3.5)

        // Audio file should be present in the extracted archive
        XCTAssertEqual(readBack.referenceAudioURLs.count, 1)
        if let extractedAudioURL = readBack.referenceAudioURLs.first {
            let extractedData = try Data(contentsOf: extractedAudioURL)
            XCTAssertEqual(extractedData.count, audioContent.count, "Audio file size should match")
            XCTAssertEqual(extractedData, audioContent, "Audio file content should match exactly")
        }
    }

    func testRoundtripReadExistingExampleAndRewrite() throws {
        // Read an existing example
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

        // Read original
        let original = try reader.read(from: exampleURL)

        // Write to new location
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rewrite-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(original, to: outputURL)

        // Read back the rewritten file
        let rewritten = try reader.read(from: outputURL)

        // Compare manifests
        XCTAssertEqual(rewritten.manifest.voxVersion, original.manifest.voxVersion)
        XCTAssertEqual(rewritten.manifest.id, original.manifest.id)
        XCTAssertEqual(rewritten.manifest.voice.name, original.manifest.voice.name)
        XCTAssertEqual(rewritten.manifest.voice.description, original.manifest.voice.description)
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

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sysunzip-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try writer.write(VoxFile(manifest: manifest), to: outputURL)

        // Use system unzip to verify
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

        // Also verify unzip lists manifest.json
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
