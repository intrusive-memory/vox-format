import XCTest
@testable import VoxFormat

final class EmbeddingEntryTests: XCTestCase {

    // MARK: - Helpers

    private func makeManifest(
        embeddingEntries: [String: VoxManifest.EmbeddingEntry]? = nil
    ) -> VoxManifest {
        VoxManifest(
            voxVersion: "0.2.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice with sufficient description length."
            ),
            embeddingEntries: embeddingEntries
        )
    }

    private func makeVoxFileWithEmbeddings() -> VoxFile {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "qwen3-tts-0.6b": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                engine: "qwen3-tts",
                file: "embeddings/qwen3-tts/0.6b/clone-prompt.bin",
                format: "bin",
                description: "Clone prompt for lightweight 0.6B model"
            ),
            "qwen3-tts-1.7b": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-1.7B",
                engine: "qwen3-tts",
                file: "embeddings/qwen3-tts/1.7b/clone-prompt.bin"
            )
        ]
        let manifest = makeManifest(embeddingEntries: entries)
        let embeddings: [String: Data] = [
            "qwen3-tts/0.6b/clone-prompt.bin": Data([0x00, 0x01, 0x02, 0x03]),
            "qwen3-tts/1.7b/clone-prompt.bin": Data([0x10, 0x11, 0x12, 0x13, 0x14])
        ]
        return VoxFile(manifest: manifest, embeddings: embeddings)
    }

    // MARK: - Decoding Tests

    func testDecodeManifestWithEmbeddings() throws {
        let json = """
        {
          "vox_version": "0.2.0",
          "id": "b3e4f5a6-7c8d-4e9f-a0b1-c2d3e4f5a6b7",
          "created": "2026-02-21T00:00:00Z",
          "voice": {
            "name": "NARRATOR",
            "description": "A warm narrator voice for testing embedding metadata."
          },
          "embeddings": {
            "qwen3-tts-0.6b": {
              "model": "Qwen/Qwen3-TTS-12Hz-0.6B",
              "engine": "qwen3-tts",
              "file": "embeddings/qwen3-tts/0.6b/clone-prompt.bin",
              "format": "bin",
              "description": "Clone prompt for lightweight 0.6B model"
            },
            "qwen3-tts-1.7b": {
              "model": "Qwen/Qwen3-TTS-12Hz-1.7B",
              "engine": "qwen3-tts",
              "file": "embeddings/qwen3-tts/1.7b/clone-prompt.bin"
            }
          }
        }
        """

        let data = json.data(using: .utf8)!
        let manifest = try VoxManifest.decoder().decode(VoxManifest.self, from: data)

        XCTAssertNotNil(manifest.embeddingEntries)
        XCTAssertEqual(manifest.embeddingEntries?.count, 2)

        let entry06b = manifest.embeddingEntries?["qwen3-tts-0.6b"]
        XCTAssertEqual(entry06b?.model, "Qwen/Qwen3-TTS-12Hz-0.6B")
        XCTAssertEqual(entry06b?.engine, "qwen3-tts")
        XCTAssertEqual(entry06b?.file, "embeddings/qwen3-tts/0.6b/clone-prompt.bin")
        XCTAssertEqual(entry06b?.format, "bin")
        XCTAssertEqual(entry06b?.description, "Clone prompt for lightweight 0.6B model")

        let entry17b = manifest.embeddingEntries?["qwen3-tts-1.7b"]
        XCTAssertEqual(entry17b?.model, "Qwen/Qwen3-TTS-12Hz-1.7B")
        XCTAssertNil(entry17b?.format)
        XCTAssertNil(entry17b?.description)
    }

    func testDecodeManifestWithoutEmbeddings_BackwardCompat() throws {
        let json = """
        {
          "vox_version": "0.1.0",
          "id": "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
          "created": "2026-02-13T12:00:00Z",
          "voice": {
            "name": "Narrator",
            "description": "A warm, clear narrator voice with neutral accent suitable for audiobooks."
          }
        }
        """

        let data = json.data(using: .utf8)!
        let manifest = try VoxManifest.decoder().decode(VoxManifest.self, from: data)

        XCTAssertNil(manifest.embeddingEntries)
    }

    func testRoundtripEncodeDecodeEmbeddings() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "qwen3-tts-0.6b": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                engine: "qwen3-tts",
                file: "embeddings/qwen3-tts/0.6b/clone-prompt.bin",
                format: "bin",
                description: "Test embedding"
            )
        ]
        let original = makeManifest(embeddingEntries: entries)

        let jsonData = try VoxManifest.encoder().encode(original)
        let decoded = try VoxManifest.decoder().decode(VoxManifest.self, from: jsonData)

        XCTAssertEqual(decoded.embeddingEntries?.count, 1)
        let entry = decoded.embeddingEntries?["qwen3-tts-0.6b"]
        XCTAssertEqual(entry?.model, "Qwen/Qwen3-TTS-12Hz-0.6B")
        XCTAssertEqual(entry?.engine, "qwen3-tts")
        XCTAssertEqual(entry?.file, "embeddings/qwen3-tts/0.6b/clone-prompt.bin")
        XCTAssertEqual(entry?.format, "bin")
        XCTAssertEqual(entry?.description, "Test embedding")
    }

    func testEncodingProducesEmbeddingsKey() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "test": VoxManifest.EmbeddingEntry(
                model: "TestModel",
                file: "embeddings/test/model.bin"
            )
        ]
        let manifest = makeManifest(embeddingEntries: entries)

        let jsonData = try VoxManifest.encoder().encode(manifest)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // JSON key should be "embeddings", not "embeddingEntries"
        XCTAssertTrue(jsonString.contains("\"embeddings\""))
        XCTAssertFalse(jsonString.contains("embeddingEntries"))
    }

    // MARK: - VoxModelQueryable Tests

    func testSupportsModel_ExactKeyMatch() {
        let vox = makeVoxFileWithEmbeddings()
        XCTAssertTrue(vox.supportsModel("qwen3-tts-0.6b"))
        XCTAssertTrue(vox.supportsModel("qwen3-tts-1.7b"))
    }

    func testSupportsModel_CaseInsensitiveKeyMatch() {
        let vox = makeVoxFileWithEmbeddings()
        XCTAssertTrue(vox.supportsModel("QWEN3-TTS-0.6B"))
        XCTAssertTrue(vox.supportsModel("Qwen3-TTS-1.7b"))
    }

    func testSupportsModel_ModelSubstringMatch() {
        let vox = makeVoxFileWithEmbeddings()
        XCTAssertTrue(vox.supportsModel("0.6B"))
        XCTAssertTrue(vox.supportsModel("1.7b"))
        XCTAssertTrue(vox.supportsModel("Qwen/Qwen3-TTS-12Hz-0.6B"))
        XCTAssertTrue(vox.supportsModel("Qwen/Qwen3-TTS-12Hz-1.7B"))
    }

    func testSupportsModel_UnknownReturnsFalse() {
        let vox = makeVoxFileWithEmbeddings()
        XCTAssertFalse(vox.supportsModel("3.0b"))
        XCTAssertFalse(vox.supportsModel("whisper"))
        XCTAssertFalse(vox.supportsModel(""))
    }

    func testSupportsModel_NoEmbeddingEntries() {
        let manifest = makeManifest(embeddingEntries: nil)
        let vox = VoxFile(manifest: manifest)
        XCTAssertFalse(vox.supportsModel("0.6b"))
    }

    func testEmbeddingData_ReturnsCorrectBinary() {
        let vox = makeVoxFileWithEmbeddings()

        let data06b = vox.embeddingData(for: "0.6b")
        XCTAssertNotNil(data06b)
        XCTAssertEqual(data06b, Data([0x00, 0x01, 0x02, 0x03]))

        let data17b = vox.embeddingData(for: "1.7b")
        XCTAssertNotNil(data17b)
        XCTAssertEqual(data17b, Data([0x10, 0x11, 0x12, 0x13, 0x14]))
    }

    func testEmbeddingData_UnknownReturnsNil() {
        let vox = makeVoxFileWithEmbeddings()
        XCTAssertNil(vox.embeddingData(for: "3.0b"))
    }

    func testSupportedModels_ListsAll() {
        let vox = makeVoxFileWithEmbeddings()
        let models = vox.supportedModels.sorted()
        XCTAssertEqual(models, [
            "Qwen/Qwen3-TTS-12Hz-0.6B",
            "Qwen/Qwen3-TTS-12Hz-1.7B"
        ])
    }

    func testSupportedModels_EmptyWhenNoEntries() {
        let manifest = makeManifest(embeddingEntries: nil)
        let vox = VoxFile(manifest: manifest)
        XCTAssertTrue(vox.supportedModels.isEmpty)
    }

    func testEmbeddingEntry_ReturnsMatchingEntry() {
        let vox = makeVoxFileWithEmbeddings()

        let entry = vox.embeddingEntry(for: "0.6b")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.model, "Qwen/Qwen3-TTS-12Hz-0.6B")
        XCTAssertEqual(entry?.engine, "qwen3-tts")
    }

    // MARK: - Validator Tests

    func testValidatorAcceptsValidEmbeddingEntries() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "qwen3-tts-0.6b": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                file: "embeddings/qwen3-tts/0.6b/clone-prompt.bin"
            )
        ]
        let manifest = makeManifest(embeddingEntries: entries)
        let validator = VoxValidator()
        XCTAssertNoThrow(try validator.validate(manifest))
    }

    func testValidatorRejectsEmptyModel() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "bad-entry": VoxManifest.EmbeddingEntry(
                model: "",
                file: "embeddings/test/model.bin"
            )
        ]
        let manifest = makeManifest(embeddingEntries: entries)
        let validator = VoxValidator()

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard case VoxError.validationErrors(let errors) = error else {
                XCTFail("Expected validationErrors"); return
            }
            let hasEmbeddingError = errors.contains { e in
                if case .invalidEmbeddingEntry(let key, let reason) = e {
                    return key == "bad-entry" && reason.contains("model")
                }
                return false
            }
            XCTAssertTrue(hasEmbeddingError)
        }
    }

    func testValidatorRejectsEmptyFile() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "bad-entry": VoxManifest.EmbeddingEntry(
                model: "SomeModel",
                file: ""
            )
        ]
        let manifest = makeManifest(embeddingEntries: entries)
        let validator = VoxValidator()

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard case VoxError.validationErrors(let errors) = error else {
                XCTFail("Expected validationErrors"); return
            }
            let hasEmbeddingError = errors.contains { e in
                if case .invalidEmbeddingEntry(_, let reason) = e {
                    return reason.contains("file")
                }
                return false
            }
            XCTAssertTrue(hasEmbeddingError)
        }
    }

    func testValidatorRejectsBadFilePath() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "bad-path": VoxManifest.EmbeddingEntry(
                model: "SomeModel",
                file: "reference/wrong-dir/model.bin"
            )
        ]
        let manifest = makeManifest(embeddingEntries: entries)
        let validator = VoxValidator()

        XCTAssertThrowsError(try validator.validate(manifest)) { error in
            guard case VoxError.validationErrors(let errors) = error else {
                XCTFail("Expected validationErrors"); return
            }
            let hasEmbeddingError = errors.contains { e in
                if case .invalidEmbeddingEntry(_, let reason) = e {
                    return reason.contains("embeddings/")
                }
                return false
            }
            XCTAssertTrue(hasEmbeddingError)
        }
    }

    func testValidatorAcceptsNoEmbeddingEntries() throws {
        let manifest = makeManifest(embeddingEntries: nil)
        let validator = VoxValidator()
        XCTAssertNoThrow(try validator.validate(manifest))
    }
}
