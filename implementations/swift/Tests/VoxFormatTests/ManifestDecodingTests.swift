import XCTest
@testable import VoxFormat

final class ManifestDecodingTests: XCTestCase {

    // MARK: - Decoding Tests

    func testDecodeMinimalManifest() throws {
        let json = """
        {
          "vox_version": "0.1.0",
          "id": "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
          "created": "2026-02-13T12:00:00Z",
          "voice": {
            "name": "Narrator",
            "description": "A warm, clear narrator voice with neutral accent suitable for audiobooks and documentaries."
          }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = VoxManifest.decoder()

        let manifest = try decoder.decode(VoxManifest.self, from: data)

        XCTAssertEqual(manifest.voxVersion, "0.1.0")
        XCTAssertEqual(manifest.id, "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78")
        XCTAssertEqual(manifest.voice.name, "Narrator")
        XCTAssertEqual(manifest.voice.description, "A warm, clear narrator voice with neutral accent suitable for audiobooks and documentaries.")
        XCTAssertNil(manifest.prosody)
        XCTAssertNil(manifest.referenceAudio)
        XCTAssertNil(manifest.character)
        XCTAssertNil(manifest.provenance)
    }

    func testDecodeCharacterManifestWithContext() throws {
        let json = """
        {
          "vox_version": "0.1.0",
          "id": "cccb2a22-1d46-440f-bb8e-9fb93963e199",
          "created": "2026-02-13T12:00:00Z",
          "voice": {
            "name": "NARRATOR",
            "description": "Male, 40s-50s, British. Rich baritone with theatrical training. Measured, authoritative delivery with subtle warmth. RP accent with precise diction suitable for literary narration.",
            "language": "en-GB",
            "gender": "male",
            "age_range": [45, 55],
            "tags": ["narrator", "authoritative", "theatrical", "literary", "british"]
          },
          "prosody": {
            "pitch_base": "low",
            "pitch_range": "moderate",
            "rate": "moderate",
            "energy": "medium",
            "emotion_default": "calm authority"
          },
          "character": {
            "role": "Omniscient narrator. Provides historical and emotional context, guides the audience through the story's moral complexities.",
            "emotional_range": ["contemplative", "melancholic", "wry", "compassionate", "stern"],
            "relationships": {
              "PROTAGONIST": "Observer and chronicler, maintains emotional distance while showing deep understanding.",
              "ANTAGONIST": "Critical but fair, reveals complexity beneath surface judgments."
            },
            "source": {
              "work": "The Chronicle",
              "format": "fountain",
              "file": "episodes/chronicle-episode-01.fountain"
            }
          },
          "provenance": {
            "method": "designed",
            "engine": "qwen3-tts-voicedesign-1.7b",
            "consent": null,
            "license": "CC0-1.0",
            "notes": "Voice designed from character description for screenplay production. Not cloned from a real person."
          }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = VoxManifest.decoder()

        let manifest = try decoder.decode(VoxManifest.self, from: data)

        XCTAssertEqual(manifest.voxVersion, "0.1.0")
        XCTAssertEqual(manifest.voice.name, "NARRATOR")
        XCTAssertEqual(manifest.voice.language, "en-GB")
        XCTAssertEqual(manifest.voice.gender, "male")
        XCTAssertEqual(manifest.voice.ageRange, [45, 55])
        XCTAssertEqual(manifest.voice.tags?.count, 5)

        XCTAssertNotNil(manifest.prosody)
        XCTAssertEqual(manifest.prosody?.pitchBase, "low")
        XCTAssertEqual(manifest.prosody?.pitchRange, "moderate")
        XCTAssertEqual(manifest.prosody?.rate, "moderate")
        XCTAssertEqual(manifest.prosody?.energy, "medium")
        XCTAssertEqual(manifest.prosody?.emotionDefault, "calm authority")

        XCTAssertNotNil(manifest.character)
        XCTAssertEqual(manifest.character?.emotionalRange?.count, 5)
        XCTAssertEqual(manifest.character?.relationships?.count, 2)
        XCTAssertEqual(manifest.character?.source?.work, "The Chronicle")
        XCTAssertEqual(manifest.character?.source?.format, "fountain")

        XCTAssertNotNil(manifest.provenance)
        XCTAssertEqual(manifest.provenance?.method, "designed")
        XCTAssertEqual(manifest.provenance?.engine, "qwen3-tts-voicedesign-1.7b")
        XCTAssertEqual(manifest.provenance?.license, "CC0-1.0")
    }

    func testDecodeMultiEngineManifest() throws {
        let json = """
        {
          "vox_version": "0.1.0",
          "id": "7ca7b257-e94a-43ae-adae-c60116fb8a8a",
          "created": "2026-02-13T12:00:00Z",
          "voice": {
            "name": "VERSATILE",
            "description": "Male, 30s, American. Versatile voice suitable for multiple genres: conversational, professional, warm and engaging. Medium pitch with clear articulation and neutral Midwest accent.",
            "language": "en-US",
            "gender": "male",
            "age_range": [28, 35],
            "tags": ["versatile", "professional", "conversational", "neutral"]
          },
          "prosody": {
            "pitch_base": "medium",
            "pitch_range": "moderate",
            "rate": "medium",
            "energy": "medium",
            "emotion_default": "friendly professionalism"
          },
          "extensions": {
            "apple": {
              "voice_id": "en-US/Aaron",
              "fallback": true
            },
            "elevenlabs": {
              "voice_id": "vid-example-abc123",
              "model_id": "eleven_multilingual_v2"
            },
            "qwen3-tts": {
              "model": "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
              "design_instruct": "A versatile American male voice in his 30s, medium pitch, clear and professional with warm conversational tone."
            }
          },
          "provenance": {
            "method": "designed",
            "engine": "multi-platform",
            "consent": null,
            "license": "CC0-1.0",
            "notes": "Vendor-neutral voice designed for cross-platform compatibility. All extension data uses placeholder values."
          }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = VoxManifest.decoder()

        let manifest = try decoder.decode(VoxManifest.self, from: data)

        XCTAssertEqual(manifest.voxVersion, "0.1.0")
        XCTAssertEqual(manifest.voice.name, "VERSATILE")
        XCTAssertEqual(manifest.voice.language, "en-US")

        XCTAssertNotNil(manifest.extensions)
        XCTAssertEqual(manifest.extensions?.keys.count, 3)
        XCTAssertTrue(manifest.extensions?.keys.contains("apple") ?? false)
        XCTAssertTrue(manifest.extensions?.keys.contains("elevenlabs") ?? false)
        XCTAssertTrue(manifest.extensions?.keys.contains("qwen3-tts") ?? false)
    }

    // MARK: - Encoding Tests

    func testRoundtripEncodingDecoding() throws {
        let originalManifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "TestVoice",
                description: "A test voice for roundtrip encoding and decoding verification.",
                language: "en-US",
                gender: "neutral",
                ageRange: [25, 35],
                tags: ["test", "neutral", "clear"]
            ),
            prosody: VoxManifest.Prosody(
                pitchBase: "medium",
                pitchRange: "moderate",
                rate: "moderate",
                energy: "medium",
                emotionDefault: "neutral"
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/test.wav",
                    transcript: "This is a test audio clip.",
                    language: "en-US",
                    durationSeconds: 3.5,
                    context: "Studio recording"
                )
            ],
            character: VoxManifest.Character(
                role: "Test character",
                emotionalRange: ["neutral", "calm"],
                relationships: ["OTHER": "colleague"],
                source: VoxManifest.Source(
                    work: "Test Script",
                    format: "fountain",
                    file: "test.fountain"
                )
            ),
            provenance: VoxManifest.Provenance(
                method: "designed",
                engine: "test-engine",
                consent: nil,
                license: "CC0-1.0",
                notes: "Test voice for unit testing"
            )
        )

        let encoder = VoxManifest.encoder()
        let jsonData = try encoder.encode(originalManifest)

        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: jsonData))

        let decoder = VoxManifest.decoder()
        let decodedManifest = try decoder.decode(VoxManifest.self, from: jsonData)

        XCTAssertEqual(decodedManifest.voxVersion, originalManifest.voxVersion)
        XCTAssertEqual(decodedManifest.id, originalManifest.id)
        XCTAssertEqual(
            decodedManifest.created.timeIntervalSince1970,
            originalManifest.created.timeIntervalSince1970,
            accuracy: 1.0
        )
        XCTAssertEqual(decodedManifest.voice.name, originalManifest.voice.name)
        XCTAssertEqual(decodedManifest.voice.description, originalManifest.voice.description)
        XCTAssertEqual(decodedManifest.voice.language, originalManifest.voice.language)
        XCTAssertEqual(decodedManifest.voice.gender, originalManifest.voice.gender)
        XCTAssertEqual(decodedManifest.voice.ageRange, originalManifest.voice.ageRange)
        XCTAssertEqual(decodedManifest.voice.tags, originalManifest.voice.tags)

        XCTAssertEqual(decodedManifest.prosody?.pitchBase, originalManifest.prosody?.pitchBase)
        XCTAssertEqual(decodedManifest.prosody?.pitchRange, originalManifest.prosody?.pitchRange)
        XCTAssertEqual(decodedManifest.prosody?.rate, originalManifest.prosody?.rate)
        XCTAssertEqual(decodedManifest.prosody?.energy, originalManifest.prosody?.energy)
        XCTAssertEqual(decodedManifest.prosody?.emotionDefault, originalManifest.prosody?.emotionDefault)

        XCTAssertEqual(decodedManifest.referenceAudio?.count, originalManifest.referenceAudio?.count)
        XCTAssertEqual(decodedManifest.referenceAudio?.first?.file, originalManifest.referenceAudio?.first?.file)
        XCTAssertEqual(decodedManifest.referenceAudio?.first?.transcript, originalManifest.referenceAudio?.first?.transcript)

        XCTAssertEqual(decodedManifest.character?.role, originalManifest.character?.role)
        XCTAssertEqual(decodedManifest.character?.emotionalRange, originalManifest.character?.emotionalRange)
        XCTAssertEqual(decodedManifest.character?.relationships, originalManifest.character?.relationships)
        XCTAssertEqual(decodedManifest.character?.source?.work, originalManifest.character?.source?.work)

        XCTAssertEqual(decodedManifest.provenance?.method, originalManifest.provenance?.method)
        XCTAssertEqual(decodedManifest.provenance?.engine, originalManifest.provenance?.engine)
        XCTAssertEqual(decodedManifest.provenance?.license, originalManifest.provenance?.license)
        XCTAssertEqual(decodedManifest.provenance?.notes, originalManifest.provenance?.notes)
    }

    // MARK: - v0.3.0 Field Tests

    func testDecodeReferenceAudioWithModelAndEngine() throws {
        let json = """
        {
          "vox_version": "0.3.0",
          "id": "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
          "created": "2026-02-13T12:00:00Z",
          "voice": {
            "name": "Test",
            "description": "A test voice for model-tagged reference audio."
          },
          "reference_audio": [
            {
              "file": "reference/sample-01.wav",
              "transcript": "Hello world.",
              "model": "Qwen/Qwen3-TTS-12Hz-1.7B",
              "engine": "qwen3-tts"
            },
            {
              "file": "reference/sample-02.wav",
              "transcript": "Universal clip."
            }
          ]
        }
        """

        let data = json.data(using: .utf8)!
        let manifest = try VoxManifest.decoder().decode(VoxManifest.self, from: data)

        XCTAssertEqual(manifest.referenceAudio?.count, 2)
        XCTAssertEqual(manifest.referenceAudio?[0].model, "Qwen/Qwen3-TTS-12Hz-1.7B")
        XCTAssertEqual(manifest.referenceAudio?[0].engine, "qwen3-tts")
        XCTAssertNil(manifest.referenceAudio?[1].model)
        XCTAssertNil(manifest.referenceAudio?[1].engine)
    }

    func testDecodeProvenanceWithSourceAndSynthesized() throws {
        let json = """
        {
          "vox_version": "0.3.0",
          "id": "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
          "created": "2026-02-13T12:00:00Z",
          "voice": {
            "name": "Test",
            "description": "A test voice for synthesized provenance."
          },
          "provenance": {
            "method": "synthesized",
            "engine": "qwen3-tts-1.7b",
            "consent": null,
            "license": "CC0-1.0"
          }
        }
        """

        let data = json.data(using: .utf8)!
        let manifest = try VoxManifest.decoder().decode(VoxManifest.self, from: data)

        XCTAssertEqual(manifest.provenance?.method, "synthesized")
    }

    func testDecodeProvenanceWithClonedSource() throws {
        let json = """
        {
          "vox_version": "0.3.0",
          "id": "ad7aa7d7-570d-4f9e-99da-1bd14b99cc78",
          "created": "2026-02-13T12:00:00Z",
          "voice": {
            "name": "ClonedVoice",
            "description": "A cloned voice with full provenance."
          },
          "provenance": {
            "method": "cloned",
            "engine": "coqui-xtts",
            "consent": "self",
            "source": ["reference/source-recording-01.wav", "reference/source-recording-02.wav"],
            "license": "CC-BY-4.0"
          }
        }
        """

        let data = json.data(using: .utf8)!
        let manifest = try VoxManifest.decoder().decode(VoxManifest.self, from: data)

        XCTAssertEqual(manifest.provenance?.method, "cloned")
        XCTAssertEqual(manifest.provenance?.consent, "self")
        XCTAssertEqual(manifest.provenance?.source, ["reference/source-recording-01.wav", "reference/source-recording-02.wav"])
    }

    func testRoundtripReferenceAudioModelFields() throws {
        let original = VoxManifest(
            voxVersion: "0.3.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "RoundtripModel",
                description: "Testing model field roundtrip on reference audio."
            ),
            referenceAudio: [
                VoxManifest.ReferenceAudio(
                    file: "reference/test.wav",
                    transcript: "Hello",
                    model: "Qwen/Qwen3-TTS-12Hz-0.6B",
                    engine: "qwen3-tts"
                )
            ]
        )

        let data = try VoxManifest.encoder().encode(original)
        let decoded = try VoxManifest.decoder().decode(VoxManifest.self, from: data)

        XCTAssertEqual(decoded.referenceAudio?.first?.model, "Qwen/Qwen3-TTS-12Hz-0.6B")
        XCTAssertEqual(decoded.referenceAudio?.first?.engine, "qwen3-tts")
    }

    func testRoundtripProvenanceSource() throws {
        let original = VoxManifest(
            voxVersion: "0.3.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "RoundtripCloned",
                description: "Testing source field roundtrip on provenance."
            ),
            provenance: VoxManifest.Provenance(
                method: "cloned",
                consent: "self",
                source: ["reference/source.wav"]
            )
        )

        let data = try VoxManifest.encoder().encode(original)
        let decoded = try VoxManifest.decoder().decode(VoxManifest.self, from: data)

        XCTAssertEqual(decoded.provenance?.source, ["reference/source.wav"])
        XCTAssertEqual(decoded.provenance?.method, "cloned")
    }

    func testEncodingProducesSnakeCaseKeys() throws {
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: "12345678-1234-4234-8234-123456789abc",
            created: Date(timeIntervalSince1970: 1707825600),
            voice: VoxManifest.Voice(
                name: "Test",
                description: "Test voice for key format verification.",
                ageRange: [30, 40]
            ),
            prosody: VoxManifest.Prosody(
                pitchBase: "medium",
                emotionDefault: "neutral"
            )
        )

        let encoder = VoxManifest.encoder()
        let jsonData = try encoder.encode(manifest)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("vox_version"))
        XCTAssertTrue(jsonString.contains("age_range"))
        XCTAssertTrue(jsonString.contains("pitch_base"))
        XCTAssertTrue(jsonString.contains("emotion_default"))

        XCTAssertFalse(jsonString.contains("voxVersion"))
        XCTAssertFalse(jsonString.contains("ageRange"))
        XCTAssertFalse(jsonString.contains("pitchBase"))
        XCTAssertFalse(jsonString.contains("emotionDefault"))
    }
}
