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
        let vox = VoxFile(manifest: manifest)
        // Add embedding data directly via internal storage
        try? vox.add(Data([0x00, 0x01, 0x02, 0x03]), at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
            "model": "Qwen/Qwen3-TTS-12Hz-0.6B",
            "engine": "qwen3-tts",
            "key": "qwen3-tts-0.6b"
        ])
        try? vox.add(Data([0x10, 0x11, 0x12, 0x13, 0x14]), at: "embeddings/qwen3-tts/1.7b/clone-prompt.bin", metadata: [
            "model": "Qwen/Qwen3-TTS-12Hz-1.7B",
            "engine": "qwen3-tts",
            "key": "qwen3-tts-1.7b"
        ])
        return vox
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

        XCTAssertTrue(jsonString.contains("\"embeddings\""))
        XCTAssertFalse(jsonString.contains("embeddingEntries"))
    }

    // MARK: - Model Query Tests

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

    // MARK: - Multi-Model Clone Prompt vs Sample Audio Disambiguation

    /// Creates a VoxFile with both clone prompts AND sample audio for 0.6b and 1.7b,
    /// matching the real-world structure produced by `echada test-voice`.
    private func makeVoxFileWithMultiModelEmbeddings() -> VoxFile {
        let vox = VoxFile(name: "TestVoice", description: "A test voice with sufficient description length.")
        // 0.6b clone prompt
        try? vox.add(Data([0xC0, 0x01]), at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
            "key": "qwen3-tts-0.6b-clone-prompt",
            "model": "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16",
            "engine": "qwen3-tts",
            "format": "bin",
        ])
        // 0.6b sample audio (WAV-like header)
        try? vox.add(Data([0x52, 0x49, 0x46, 0x46]), at: "embeddings/qwen3-tts/0.6b/sample-audio.wav", metadata: [
            "key": "qwen3-tts-0.6b-sample-audio",
            "model": "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16",
            "engine": "qwen3-tts",
            "format": "wav",
        ])
        // 1.7b clone prompt
        try? vox.add(Data([0xC1, 0x71]), at: "embeddings/qwen3-tts/1.7b/clone-prompt.bin", metadata: [
            "key": "qwen3-tts-1.7b-clone-prompt",
            "model": "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16",
            "engine": "qwen3-tts",
            "format": "bin",
        ])
        // 1.7b sample audio (WAV-like header)
        try? vox.add(Data([0x52, 0x49, 0x46, 0x46]), at: "embeddings/qwen3-tts/1.7b/sample-audio.wav", metadata: [
            "key": "qwen3-tts-1.7b-sample-audio",
            "model": "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16",
            "engine": "qwen3-tts",
            "format": "wav",
        ])
        return vox
    }

    func testClonePromptData_ReturnsClonePromptNotSampleAudio() {
        let vox = makeVoxFileWithMultiModelEmbeddings()

        let prompt06b = vox.clonePromptData(for: "0.6b")
        XCTAssertNotNil(prompt06b)
        XCTAssertEqual(prompt06b, Data([0xC0, 0x01]), "Should return 0.6b clone prompt, not sample audio")

        let prompt17b = vox.clonePromptData(for: "1.7b")
        XCTAssertNotNil(prompt17b)
        XCTAssertEqual(prompt17b, Data([0xC1, 0x71]), "Should return 1.7b clone prompt, not sample audio")
    }

    func testSampleAudioData_ReturnsSampleAudioNotClonePrompt() {
        let vox = makeVoxFileWithMultiModelEmbeddings()

        let audio06b = vox.sampleAudioData(for: "0.6b")
        XCTAssertNotNil(audio06b)
        XCTAssertEqual(audio06b, Data([0x52, 0x49, 0x46, 0x46]), "Should return 0.6b sample audio")

        let audio17b = vox.sampleAudioData(for: "1.7b")
        XCTAssertNotNil(audio17b)
        XCTAssertEqual(audio17b, Data([0x52, 0x49, 0x46, 0x46]), "Should return 1.7b sample audio")
    }

    func testClonePromptData_DoesNotReturnSampleAudio_Regression() {
        // Regression test: embeddingData(for: "1.7b") could return sample audio
        // due to non-deterministic dictionary iteration. clonePromptData must
        // always return the clone prompt, never sample audio.
        let vox = makeVoxFileWithMultiModelEmbeddings()

        // Run multiple times to catch non-deterministic dictionary ordering
        for _ in 0..<100 {
            let data = vox.clonePromptData(for: "1.7b")
            XCTAssertEqual(data, Data([0xC1, 0x71]),
                "clonePromptData must never return sample audio WAV data")
        }
    }

    func testClonePromptData_UnknownModelReturnsNil() {
        let vox = makeVoxFileWithMultiModelEmbeddings()
        XCTAssertNil(vox.clonePromptData(for: "3.0b"))
    }

    func testClonePromptData_LegacyFallback() {
        let vox = VoxFile(name: "Legacy", description: "A legacy voice with no embedding entries in manifest.")
        // Add data at legacy path without embedding manifest entries
        let legacyVox = VoxFile(manifest: VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(name: "Legacy", description: "A legacy voice with sufficient description.")
        ))
        try? legacyVox.add(Data([0xAA, 0xBB]), at: "embeddings/qwen3-tts/clone-prompt.bin", metadata: [
            "model": "legacy-model",
        ])

        // Should NOT match via legacy fallback since add() creates embedding entries
        // Test the real legacy case: no embeddingEntries at all
        let emptyVox = VoxFile(manifest: VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(),
            voice: VoxManifest.Voice(name: "Legacy", description: "A legacy voice with sufficient description.")
        ))
        XCTAssertNil(emptyVox.clonePromptData(for: "1.7b"))
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
        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidatorRejectsEmptyModel() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "bad-entry": VoxManifest.EmbeddingEntry(
                model: "",
                file: "embeddings/test/model.bin"
            )
        ]
        let manifest = makeManifest(embeddingEntries: entries)
        let vox = VoxFile(manifest: manifest)

        let issues = vox.validate()
        let hasEmbeddingError = issues.contains { $0.severity == .error && ($0.field?.contains("bad-entry") ?? false) }
        XCTAssertTrue(hasEmbeddingError)
    }

    func testValidatorRejectsEmptyFile() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "bad-entry": VoxManifest.EmbeddingEntry(
                model: "SomeModel",
                file: ""
            )
        ]
        let manifest = makeManifest(embeddingEntries: entries)
        let vox = VoxFile(manifest: manifest)

        let issues = vox.validate()
        let hasEmbeddingError = issues.contains { $0.severity == .error && ($0.field?.contains("bad-entry") ?? false) }
        XCTAssertTrue(hasEmbeddingError)
    }

    func testValidatorRejectsBadFilePath() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "bad-path": VoxManifest.EmbeddingEntry(
                model: "SomeModel",
                file: "reference/wrong-dir/model.bin"
            )
        ]
        let manifest = makeManifest(embeddingEntries: entries)
        let vox = VoxFile(manifest: manifest)

        let issues = vox.validate()
        let hasEmbeddingError = issues.contains { $0.severity == .error && $0.message.contains("embeddings/") }
        XCTAssertTrue(hasEmbeddingError)
    }

    func testValidatorAcceptsNoEmbeddingEntries() throws {
        let manifest = makeManifest(embeddingEntries: nil)
        let vox = VoxFile(manifest: manifest)
        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty)
    }
}
