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
        let voxFile = VoxFile(manifest: manifest)

        let migrated = VoxMigrator.migrate(voxFile)

        XCTAssertEqual(migrated.manifest.voxVersion, VoxFormat.currentVersion)
        XCTAssertNil(migrated.manifest.embeddingEntries)
    }

    func testMigrateV1WithBinaries_InfersEmbeddingEntries() {
        let manifest = makeV1Manifest()
        let embeddings: [String: Data] = [
            "qwen3-tts/0.6b/clone-prompt.bin": Data([0x01, 0x02, 0x03])
        ]
        let voxFile = VoxFile(manifest: manifest, embeddings: embeddings)

        let migrated = VoxMigrator.migrate(voxFile)

        XCTAssertEqual(migrated.manifest.voxVersion, VoxFormat.currentVersion)
        XCTAssertNotNil(migrated.manifest.embeddingEntries)
        XCTAssertEqual(migrated.manifest.embeddingEntries?.count, 1)

        // Key should be derived from directory path
        let entry = migrated.manifest.embeddingEntries?["qwen3-tts-0.6b"]
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
        let embeddings: [String: Data] = [
            "qwen3-tts/0.6b/clone-prompt.bin": Data([0x01, 0x02])
        ]
        let voxFile = VoxFile(manifest: manifest, embeddings: embeddings)

        let migrated = VoxMigrator.migrate(voxFile)

        XCTAssertNotNil(migrated.manifest.embeddingEntries)
        // Should use the model name from extensions
        let entries = migrated.manifest.embeddingEntries!
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
        let embeddings: [String: Data] = [
            "qwen3-tts/0.6b/clone-prompt.bin": Data([0x01, 0x02])
        ]
        let voxFile = VoxFile(manifest: manifest, embeddings: embeddings)

        let migrated = VoxMigrator.migrate(voxFile)

        XCTAssertEqual(migrated.manifest.voxVersion, VoxFormat.currentVersion)
        XCTAssertEqual(migrated.manifest.embeddingEntries?.count, 1)
        XCTAssertEqual(
            migrated.manifest.embeddingEntries?["qwen3-tts-0.6b"]?.model,
            "Qwen/Qwen3-TTS-12Hz-0.6B"
        )
    }

    func testMigrateMultipleBinaries_CreatesMultipleEntries() {
        let manifest = makeV1Manifest()
        let embeddings: [String: Data] = [
            "qwen3-tts/0.6b/clone-prompt.bin": Data([0x01]),
            "qwen3-tts/1.7b/clone-prompt.bin": Data([0x02])
        ]
        let voxFile = VoxFile(manifest: manifest, embeddings: embeddings)

        let migrated = VoxMigrator.migrate(voxFile)

        XCTAssertEqual(migrated.manifest.embeddingEntries?.count, 2)
    }

    // MARK: - Readiness Tests

    func testReadiness_Ready_AllPresent() {
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
        let voxFile = VoxFile(
            manifest: manifest,
            embeddings: ["qwen3-tts/0.6b/clone-prompt.bin": Data([0x01])]
        )

        XCTAssertEqual(voxFile.readiness, .ready)
        XCTAssertTrue(voxFile.isReady)
        XCTAssertFalse(voxFile.needsRegeneration)
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
        // No embeddings data — binary is missing
        let voxFile = VoxFile(manifest: manifest)

        XCTAssertFalse(voxFile.isReady)
        XCTAssertTrue(voxFile.needsRegeneration)
        if case .needsRegeneration(let missing) = voxFile.readiness {
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
        let voxFile = VoxFile(manifest: manifest)

        if case .invalid(let reasons) = voxFile.readiness {
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
        let voxFile = VoxFile(manifest: manifest)

        XCTAssertEqual(voxFile.readiness, .ready)
    }

    // MARK: - Bundle Validation Tests

    func testValidateBundle_AllPresent_NoThrow() throws {
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
        let voxFile = VoxFile(
            manifest: manifest,
            embeddings: ["qwen3-tts/0.6b/clone-prompt.bin": Data([0x01])]
        )

        let validator = VoxValidator()
        XCTAssertNoThrow(try validator.validateBundle(voxFile))
    }

    func testValidateBundle_MissingEmbedding_Throws() throws {
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
        let voxFile = VoxFile(manifest: manifest)

        let validator = VoxValidator()
        XCTAssertThrowsError(try validator.validateBundle(voxFile)) { error in
            guard case VoxError.validationErrors(let errors) = error else {
                XCTFail("Expected validationErrors"); return
            }
            let hasMissing = errors.contains { e in
                if case .missingBundledFile(_, let section) = e {
                    return section == "embeddings"
                }
                return false
            }
            XCTAssertTrue(hasMissing)
        }
    }

    func testValidateBundle_MissingRefAudio_Throws() throws {
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
        // No reference audio data
        let voxFile = VoxFile(manifest: manifest)

        let validator = VoxValidator()
        XCTAssertThrowsError(try validator.validateBundle(voxFile)) { error in
            guard case VoxError.validationErrors(let errors) = error else {
                XCTFail("Expected validationErrors"); return
            }
            let hasMissing = errors.contains { e in
                if case .missingBundledFile(_, let section) = e {
                    return section == "reference_audio"
                }
                return false
            }
            XCTAssertTrue(hasMissing)
        }
    }

    // MARK: - Roundtrip Migration Tests

    func testRoundtripMigratedFile() throws {
        // Create a v0.1.0 file with embeddings but no embeddingEntries
        let manifest = makeV1Manifest()
        let embeddings: [String: Data] = [
            "qwen3-tts/0.6b/clone-prompt.bin": Data(repeating: 0xAB, count: 256)
        ]
        let original = VoxFile(manifest: manifest, embeddings: embeddings)

        // Migrate
        let migrated = VoxMigrator.migrate(original)
        XCTAssertEqual(migrated.manifest.voxVersion, VoxFormat.currentVersion)
        XCTAssertNotNil(migrated.manifest.embeddingEntries)

        // Write
        let writer = VoxWriter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-roundtrip-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        try writer.write(migrated, to: outputURL)

        // Read back
        let reader = VoxReader()
        let readBack = try reader.read(from: outputURL)

        XCTAssertEqual(readBack.manifest.voxVersion, VoxFormat.currentVersion)
        XCTAssertNotNil(readBack.manifest.embeddingEntries)
        XCTAssertEqual(readBack.embeddings.count, 1)
        XCTAssertEqual(
            readBack.embeddings["qwen3-tts/0.6b/clone-prompt.bin"],
            embeddings["qwen3-tts/0.6b/clone-prompt.bin"]
        )
    }

    func testReaderAutoMigrates() throws {
        // Create a v0.1.0 file with embedding binary but no embeddingEntries
        let manifest = makeV1Manifest()
        let embeddings: [String: Data] = [
            "qwen3-tts/0.6b/clone-prompt.bin": Data([0x01, 0x02])
        ]
        let original = VoxFile(manifest: manifest, embeddings: embeddings)

        // Write it as-is (writer stamps v0.2.0 but we want to test reader migration)
        let writer = VoxWriter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("auto-migrate-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        try writer.write(original, to: outputURL)

        // Read back — should have been auto-migrated
        let reader = VoxReader()
        let readBack = try reader.read(from: outputURL)

        XCTAssertEqual(readBack.manifest.voxVersion, VoxFormat.currentVersion)
    }

    func testWriterAlwaysStampsCurrentVersion() throws {
        // Create with old version
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with sufficient description length."
            )
        )
        let voxFile = VoxFile(manifest: manifest)

        let writer = VoxWriter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("version-stamp-\(UUID().uuidString).vox")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        try writer.write(voxFile, to: outputURL)

        // Read back and check version was stamped
        let reader = VoxReader()
        let readBack = try reader.read(from: outputURL)
        XCTAssertEqual(readBack.manifest.voxVersion, VoxFormat.currentVersion)
    }
}
