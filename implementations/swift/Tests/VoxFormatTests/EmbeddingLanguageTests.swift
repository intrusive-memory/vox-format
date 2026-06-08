import XCTest
@testable import VoxFormat

/// Tests for v0.4.0 optional per-language samples and clone prompts.
///
/// Covers the §1 / D6 fallback chain: exact language → base-language → default
/// (language-neutral) → legacy path, plus backward-compatibility guarantees.
final class EmbeddingLanguageTests: XCTestCase {

    // MARK: - Fixtures

    /// A voice carrying, for the 0.6b model:
    ///   - a default (language-neutral) sample + clone prompt
    ///   - a Spanish (`es`) sample + clone prompt
    ///   - a French-France (`fr-FR`) sample + clone prompt
    private func makeMultiLanguageVox() -> VoxFile {
        let vox = VoxFile(name: "TestVoice", description: "A test voice with sufficient description length.")
        let model = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16"

        // Default (language-neutral)
        try? vox.add(Data([0xC0, 0x00]), at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
            "model": model, "engine": "qwen3-tts", "format": "bin",
        ])
        try? vox.add(Data([0x52, 0x49, 0x46, 0x46, 0x00]), at: "embeddings/qwen3-tts/0.6b/sample-audio.wav", metadata: [
            "model": model, "engine": "qwen3-tts", "format": "wav",
        ])

        // Spanish
        try? vox.add(Data([0xC0, 0xE5]), at: "embeddings/qwen3-tts/0.6b/es/clone-prompt.bin", metadata: [
            "model": model, "engine": "qwen3-tts", "format": "bin", "language": "es",
        ])
        try? vox.add(Data([0x52, 0x49, 0x46, 0x46, 0xE5]), at: "embeddings/qwen3-tts/0.6b/es/sample-audio.wav", metadata: [
            "model": model, "engine": "qwen3-tts", "format": "wav", "language": "es",
        ])

        // French (France)
        try? vox.add(Data([0xC0, 0xFF, 0x01]), at: "embeddings/qwen3-tts/0.6b/fr-FR/clone-prompt.bin", metadata: [
            "model": model, "engine": "qwen3-tts", "format": "bin", "language": "fr-FR",
        ])
        try? vox.add(Data([0x52, 0x49, 0x46, 0x46, 0xFF]), at: "embeddings/qwen3-tts/0.6b/fr-FR/sample-audio.wav", metadata: [
            "model": model, "engine": "qwen3-tts", "format": "wav", "language": "fr-FR",
        ])

        return vox
    }

    private let defaultSample = Data([0x52, 0x49, 0x46, 0x46, 0x00])
    private let esSample = Data([0x52, 0x49, 0x46, 0x46, 0xE5])
    private let frSample = Data([0x52, 0x49, 0x46, 0x46, 0xFF])
    private let defaultPrompt = Data([0xC0, 0x00])
    private let esPrompt = Data([0xC0, 0xE5])

    // MARK: - Exact-language match

    func testSampleAudio_ExactLanguageMatch() {
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "es"), esSample)
    }

    func testClonePrompt_ExactLanguageMatch() {
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.clonePromptData(for: "0.6b", language: "es"), esPrompt)
    }

    func testSampleAudio_ExactLanguageMatch_CaseInsensitive() {
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "ES"), esSample)
    }

    // MARK: - Default fallback (requested language absent)

    func testSampleAudio_FallsBackToDefault_WhenLanguageAbsent() {
        let vox = makeMultiLanguageVox()
        // German not present → default/language-neutral sample.
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "de"), defaultSample)
    }

    func testClonePrompt_FallsBackToDefault_WhenLanguageAbsent() {
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.clonePromptData(for: "0.6b", language: "de"), defaultPrompt)
    }

    // MARK: - Base-language fallback (D6)

    func testSampleAudio_BaseLanguageFallback() {
        // Voice has `es` but not `es-MX`; query `es-MX` should resolve the base `es`.
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "es-MX"), esSample)
    }

    func testSampleAudio_ExactBeatsBaseLanguage() {
        // Voice has both `fr-FR` and a default; query `fr-FR` must return the exact fr-FR,
        // not the base `fr` (which doesn't exist) and not the default.
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "fr-FR"), frSample)
    }

    func testSampleAudio_RegionQueryFallsBackToDefault_WhenNeitherExactNorBasePresent() {
        // `de-DE` → no `de-DE`, no base `de`, so default.
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "de-DE"), defaultSample)
    }

    // MARK: - nil / "default" parity with legacy single-arg API

    func testSampleAudio_NilLanguage_MatchesLegacyAndReturnsDefault() {
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: nil), defaultSample)
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b"), vox.sampleAudioData(for: "0.6b", language: nil))
    }

    func testSampleAudio_DefaultKeyword_ResolvesDefault() {
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "default"), defaultSample)
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "DEFAULT"), defaultSample)
    }

    func testClonePrompt_NilLanguage_ReturnsDefault() {
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.clonePromptData(for: "0.6b", language: nil), defaultPrompt)
        XCTAssertEqual(vox.clonePromptData(for: "0.6b"), defaultPrompt)
    }

    // MARK: - nil when nothing resolves

    func testSampleAudio_ReturnsNil_WhenModelUnknown() {
        let vox = makeMultiLanguageVox()
        XCTAssertNil(vox.sampleAudioData(for: "3.0b", language: "es"))
    }

    func testSampleAudio_ReturnsNil_WhenNoSamplesAtAll() {
        let vox = VoxFile(name: "Empty", description: "A voice with no embeddings whatsoever, just metadata.")
        XCTAssertNil(vox.sampleAudioData(for: "0.6b", language: "es"))
        XCTAssertNil(vox.sampleAudioData(for: "0.6b"))
    }

    // MARK: - Discovery helpers

    func testSampleAudioLanguages_ListsLanguageSpecificOnly() {
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.sampleAudioLanguages(for: "0.6b"), ["es", "fr-FR"])
    }

    func testClonePromptLanguages_ListsLanguageSpecificOnly() {
        let vox = makeMultiLanguageVox()
        XCTAssertEqual(vox.clonePromptLanguages(for: "0.6b"), ["es", "fr-FR"])
    }

    func testSampleAudioLanguages_EmptyWhenDefaultOnly() {
        let vox = VoxFile(name: "DefaultOnly", description: "A voice with only a default sample, no languages.")
        try? vox.add(Data([0x52, 0x49, 0x46, 0x46]), at: "embeddings/qwen3-tts/0.6b/sample-audio.wav", metadata: [
            "model": "Qwen/Qwen3-TTS-12Hz-0.6B", "engine": "qwen3-tts", "format": "wav",
        ])
        XCTAssertEqual(vox.sampleAudioLanguages(for: "0.6b"), [])
    }

    // MARK: - Key uniqueness

    func testDeriveEmbeddingKey_DistinctForDefaultVsLanguage() {
        let vox = makeMultiLanguageVox()
        let entries = vox.manifest.embeddingEntries ?? [:]
        // Default and language-specific entries coexist (no overwrite/collision).
        XCTAssertNotNil(entries["qwen3-tts-0.6b-sample-audio"])
        XCTAssertNotNil(entries["qwen3-tts-0.6b-es-sample-audio"])
        XCTAssertNotNil(entries["qwen3-tts-0.6b-fr-fr-sample-audio"]
            ?? entries["qwen3-tts-0.6b-fr-FR-sample-audio"])
        XCTAssertEqual(entries["qwen3-tts-0.6b-es-sample-audio"]?.language, "es")
        XCTAssertNil(entries["qwen3-tts-0.6b-sample-audio"]?.language)
    }

    // MARK: - Codable round-trip of the language field

    func testEmbeddingEntry_LanguageSurvivesRoundTrip() throws {
        let entries: [String: VoxManifest.EmbeddingEntry] = [
            "qwen3-tts-0.6b-es-sample-audio": VoxManifest.EmbeddingEntry(
                model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                engine: "qwen3-tts",
                file: "embeddings/qwen3-tts/0.6b/es/sample-audio.wav",
                format: "wav",
                language: "es"
            )
        ]
        let manifest = VoxManifest(
            voxVersion: "0.4.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(name: "T", description: "A test voice with sufficient description length."),
            embeddingEntries: entries
        )

        let jsonData = try VoxManifest.encoder().encode(manifest)
        let json = String(data: jsonData, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"language\""))

        let decoded = try VoxManifest.decoder().decode(VoxManifest.self, from: jsonData)
        XCTAssertEqual(decoded.embeddingEntries?["qwen3-tts-0.6b-es-sample-audio"]?.language, "es")
    }

    // MARK: - Backward compatibility (old file, no language)

    func testDecode_OldEntryWithoutLanguage_DecodesAsNil() throws {
        let json = """
        {
          "vox_version": "0.3.0",
          "id": "b3e4f5a6-7c8d-4e9f-a0b1-c2d3e4f5a6b7",
          "created": "2026-02-21T00:00:00Z",
          "voice": { "name": "N", "description": "A warm narrator voice for testing backward compat." },
          "embeddings": {
            "qwen3-tts-0.6b": {
              "model": "Qwen/Qwen3-TTS-12Hz-0.6B",
              "engine": "qwen3-tts",
              "file": "embeddings/qwen3-tts/0.6b/clone-prompt.bin"
            }
          }
        }
        """
        let manifest = try VoxManifest.decoder().decode(VoxManifest.self, from: json.data(using: .utf8)!)
        XCTAssertNil(manifest.embeddingEntries?["qwen3-tts-0.6b"]?.language)
    }

    func testOldStyleVox_LanguageQueryResolvesDefault_Regression() {
        // A voice with only language-neutral entries (the pre-0.4.0 shape): any language
        // query must resolve the default, never throw, never return nil when a default exists.
        let vox = VoxFile(name: "Legacy", description: "A pre-0.4.0 voice with only language-neutral samples.")
        let model = "Qwen/Qwen3-TTS-12Hz-0.6B"
        try? vox.add(Data([0xC0, 0x00]), at: "embeddings/qwen3-tts/0.6b/clone-prompt.bin", metadata: [
            "model": model, "engine": "qwen3-tts", "format": "bin",
        ])
        try? vox.add(defaultSample, at: "embeddings/qwen3-tts/0.6b/sample-audio.wav", metadata: [
            "model": model, "engine": "qwen3-tts", "format": "wav",
        ])

        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "es"), defaultSample)
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: "fr-FR"), defaultSample)
        XCTAssertEqual(vox.sampleAudioData(for: "0.6b", language: nil), defaultSample)
        XCTAssertEqual(vox.clonePromptData(for: "0.6b", language: "es"), Data([0xC0, 0x00]))
    }

    // MARK: - Example fixture validates through the Swift implementation

    /// Locates a repo-root-relative path from this test file (5 levels up:
    /// VoxFormatTests → Tests → swift → implementations → repo root).
    private func repoURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
    }

    /// The shipped `examples/multi-language/manifest.json` must decode and pass the
    /// pure-Swift `VoxFile.validate()` gate — the schema-conformance check that runs
    /// in CI without any external (Python/Node) validator.
    func testMultiLanguageExample_DecodesAndValidates() throws {
        let url = repoURL("examples/multi-language/manifest.json")
        let data = try Data(contentsOf: url)
        let manifest = try VoxManifest.decoder().decode(VoxManifest.self, from: data)
        let vox = VoxFile(manifest: manifest)

        let errors = vox.validate().filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, "multi-language example should validate: \(errors)")

        // The optional language field must survive the real-file round-trip.
        let entries = manifest.embeddingEntries ?? [:]
        XCTAssertEqual(entries["qwen3-tts-0.6b-es-sample-audio"]?.language, "es")
        XCTAssertEqual(entries["qwen3-tts-0.6b-fr-FR-sample-audio"]?.language, "fr-FR")
        XCTAssertNil(entries["qwen3-tts-0.6b"]?.language, "default entry stays language-neutral")
    }
}
