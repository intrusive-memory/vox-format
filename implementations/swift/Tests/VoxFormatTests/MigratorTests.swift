import XCTest
@testable import VoxFormat

final class MigratorTests: XCTestCase {

    // MARK: - Helpers

    private func makeV1Manifest(
        extensions: [String: AnyCodable]? = nil,
        embeddingEntries: [String: VoxManifest.EmbeddingEntry]? = nil
    ) -> VoxManifest {
        VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with a sufficiently long description for validation."
            ),
            extensions: extensions,
            embeddingEntries: embeddingEntries
        )
    }

    // MARK: - Migration Tests

    func testMigrateV1WithNoEmbeddings_BumpsVersion() {
        let manifest = makeV1Manifest()
        let migrated = VoxMigrator.migrateManifest(manifest, embeddingKeys: [])

        XCTAssertEqual(migrated.voxVersion, VoxFormat.currentVersion)
        XCTAssertNil(migrated.embeddingEntries)
    }

    func testMigrateV1WithBinaries_InfersEmbeddingEntries() {
        let manifest = makeV1Manifest()
        let embeddingKeys: Set<String> = ["qwen3-tts/0.6b/clone-prompt.bin"]

        let migrated = VoxMigrator.migrateManifest(manifest, embeddingKeys: embeddingKeys)

        XCTAssertEqual(migrated.voxVersion, VoxFormat.currentVersion)
        XCTAssertNotNil(migrated.embeddingEntries)
        XCTAssertEqual(migrated.embeddingEntries?.count, 1)

        let entry = migrated.embeddingEntries?["qwen3-tts-0.6b"]
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.file, "embeddings/qwen3-tts/0.6b/clone-prompt.bin")
        XCTAssertEqual(entry?.engine, "qwen3-tts")
        XCTAssertEqual(entry?.format, "bin")
    }

    func testMigrateV1WithExtensions_UsesExtensionHints() {
        let extensions: [String: AnyCodable] = [
            "qwen3-tts": AnyCodable([
                "clone_prompt": "embeddings/qwen3-tts/0.6b/clone-prompt.bin",
                "model": "Qwen/Qwen3-TTS-12Hz-0.6B"
            ] as [String: Any])
        ]
        let manifest = makeV1Manifest(extensions: extensions)
        let embeddingKeys: Set<String> = ["qwen3-tts/0.6b/clone-prompt.bin"]

        let migrated = VoxMigrator.migrateManifest(manifest, embeddingKeys: embeddingKeys)

        XCTAssertNotNil(migrated.embeddingEntries)
        let entries = migrated.embeddingEntries!
        let matchingEntry = entries.values.first { $0.model == "Qwen/Qwen3-TTS-12Hz-0.6B" }
        XCTAssertNotNil(matchingEntry, "Should find entry with model from extensions")
        XCTAssertEqual(matchingEntry?.engine, "qwen3-tts")
    }

    func testMigrateV2WithExistingEntries_PreservesEntries() {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "qwen3-tts-0.6b": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                engine: "qwen3-tts",
                file: "embeddings/qwen3-tts/0.6b/clone-prompt.bin"
            )
        ]
        let manifest = makeV1Manifest(embeddingEntries: entries)
        let embeddingKeys: Set<String> = ["qwen3-tts/0.6b/clone-prompt.bin"]

        let migrated = VoxMigrator.migrateManifest(manifest, embeddingKeys: embeddingKeys)

        XCTAssertEqual(migrated.voxVersion, VoxFormat.currentVersion)
        XCTAssertEqual(migrated.embeddingEntries?.count, 1)
        XCTAssertEqual(
            migrated.embeddingEntries?["qwen3-tts-0.6b"]?.model,
            "Qwen/Qwen3-TTS-12Hz-0.6B"
        )
    }

    func testMigrateMultipleBinaries_CreatesMultipleEntries() {
        let manifest = makeV1Manifest()
        let embeddingKeys: Set<String> = [
            "qwen3-tts/0.6b/clone-prompt.bin",
            "qwen3-tts/1.7b/clone-prompt.bin"
        ]

        let migrated = VoxMigrator.migrateManifest(manifest, embeddingKeys: embeddingKeys)

        XCTAssertEqual(migrated.embeddingEntries?.count, 2)
    }

    // MARK: - Readiness Tests

    func testReadiness_Ready_AllPresent() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "qwen3-tts-0.6b": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                file: "embeddings/qwen3-tts/0.6b/clone-prompt.bin"
            )
        ]
        let manifest = VoxManifest(
            voxVersion: "0.2.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with sufficient description length."
            ),
            embeddingEntries: entries
        )
        let vox = VoxFile(manifest: manifest)
        try vox.add(Data([0x01]), at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
            "model": "Qwen/Qwen3-TTS-12Hz-0.6B",
            "key": "qwen3-tts-0.6b"
        ])

        XCTAssertEqual(vox.readiness, .ready)
        XCTAssertTrue(vox.isReady)
        XCTAssertFalse(vox.needsRegeneration)
    }

    func testReadiness_NeedsRegeneration_MissingBinary() {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "qwen3-tts-0.6b": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                file: "embeddings/qwen3-tts/0.6b/clone-prompt.bin"
            )
        ]
        let manifest = VoxManifest(
            voxVersion: "0.2.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with sufficient description length."
            ),
            embeddingEntries: entries
        )
        let vox = VoxFile(manifest: manifest)

        XCTAssertFalse(vox.isReady)
        XCTAssertTrue(vox.needsRegeneration)
        if case .needsRegeneration(let missing) = vox.readiness {
            XCTAssertEqual(missing, ["qwen3-tts-0.6b"])
        } else {
            XCTFail("Expected needsRegeneration")
        }
    }

    func testReadiness_Invalid_ShortDescription() {
        let manifest = VoxManifest(
            voxVersion: "0.2.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "Short"
            )
        )
        let vox = VoxFile(manifest: manifest)

        if case .invalid(let reasons) = vox.readiness {
            XCTAssertTrue(reasons.first?.contains("too short") ?? false)
        } else {
            XCTFail("Expected invalid")
        }
    }

    func testReadiness_Ready_NoEmbeddingsNoRefAudio() {
        let manifest = VoxManifest(
            voxVersion: "0.2.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with sufficient description length."
            )
        )
        let vox = VoxFile(manifest: manifest)

        XCTAssertEqual(vox.readiness, .ready)
    }

    // MARK: - Bundle Validation Tests

    func testValidateBundle_AllPresent_NoWarnings() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "qwen3-tts-0.6b": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                file: "embeddings/qwen3-tts/0.6b/clone-prompt.bin"
            )
        ]
        let manifest = VoxManifest(
            voxVersion: "0.2.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with sufficient description length."
            ),
            embeddingEntries: entries
        )
        let vox = VoxFile(manifest: manifest)
        try vox.add(Data([0x01]), at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
            "model": "Qwen/Qwen3-TTS-12Hz-0.6B",
            "key": "qwen3-tts-0.6b"
        ])

        let warnings = vox.validate().filter { $0.severity == .warning }
        XCTAssertTrue(warnings.isEmpty)
    }

    func testValidateBundle_MissingEmbedding_HasWarning() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "qwen3-tts-0.6b": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                file: "embeddings/qwen3-tts/0.6b/clone-prompt.bin"
            )
        ]
        let manifest = VoxManifest(
            voxVersion: "0.2.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with sufficient description length."
            ),
            embeddingEntries: entries
        )
        let vox = VoxFile(manifest: manifest)

        let warnings = vox.validate().filter { $0.severity == .warning }
        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.message.contains("missing") })
    }

    func testValidateBundle_MissingRefAudio_HasWarning() throws {
        let manifest = VoxManifest(
            voxVersion: "0.2.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with sufficient description length."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/sample.wav",
                    transcript: "Hello world"
                )
            ]
        )
        let vox = VoxFile(manifest: manifest)

        let warnings = vox.validate().filter { $0.severity == .warning }
        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.message.contains("missing") })
    }

    // MARK: - Roundtrip Migration Tests

    func testRoundtripMigratedFile() throws {
        let manifest = makeV1Manifest()
        let vox = VoxFile(manifest: manifest)
        let embeddingData = Data(repeating: 0xAB, count: 256)
        try vox.add(embeddingData, at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
            "model": "qwen3-tts-0.6b"
        ])

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-roundtrip-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        try vox.write(to: outputURL)

        let readBack = try VoxFile(contentsOf: outputURL)

        XCTAssertEqual(readBack.manifest.voxVersion, VoxFormat.currentVersion)
        XCTAssertNotNil(readBack.manifest.embeddingEntries)
        let entry = readBack["embeddings/qwen3-tts/0.6b/clone-prompt.bin"]
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.data, embeddingData)
    }

    func testReaderAutoMigrates() throws {
        // Create a file, write it, read it back — version should be current
        let manifest = makeV1Manifest()
        let vox = VoxFile(manifest: manifest)
        try vox.add(Data([0x01, 0x02]), at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
            "model": "qwen3-tts-0.6b"
        ])

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("auto-migrate-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        try vox.write(to: outputURL)

        let readBack = try VoxFile(contentsOf: outputURL)
        XCTAssertEqual(readBack.manifest.voxVersion, VoxFormat.currentVersion)
    }

    func testWriterAlwaysStampsCurrentVersion() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with sufficient description length."
            )
        )
        let vox = VoxFile(manifest: manifest)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("version-stamp-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        try vox.write(to: outputURL)

        let readBack = try VoxFile(contentsOf: outputURL)
        XCTAssertEqual(readBack.manifest.voxVersion, VoxFormat.currentVersion)
    }
}
