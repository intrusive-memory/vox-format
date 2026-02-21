import Foundation

/// The root metadata structure for a VOX voice identity file.
///
/// `VoxManifest` represents the complete contents of the `manifest.json` file inside
/// a `.vox` archive. It defines the voice identity through required fields (version,
/// identifier, creation date, and voice metadata) and optional sections for prosody,
/// reference audio, character context, provenance, and engine-specific extensions.
///
/// Use ``VoxManifest/decoder()`` and ``VoxManifest/encoder()`` for JSON serialization
/// that handles ISO 8601 dates and snake_case key mapping automatically.
///
/// ```swift
/// let manifest = VoxManifest(
///     voxVersion: "0.1.0",
///     id: UUID().uuidString.lowercased(),
///     created: Date(),
///     voice: VoxManifest.Voice(
///         name: "Narrator",
///         description: "A warm, clear narrator voice for audiobooks."
///     )
/// )
/// let data = try VoxManifest.encoder().encode(manifest)
/// ```
public struct VoxManifest: Codable {
    /// Semantic version of the VOX format specification (e.g., `"0.2.0"`).
    public var voxVersion: String

    /// Unique identifier for this voice identity in UUID v4 format.
    public let id: String

    /// ISO 8601 timestamp of when this voice identity was created.
    public let created: Date

    /// Core voice identity metadata including name, description, and optional attributes.
    public let voice: Voice

    /// Prosodic preferences describing the voice's natural speaking style.
    public var prosody: Prosody?

    /// Reference audio clips used for voice cloning or style matching.
    public var referenceAudio: [ReferenceAudio]?

    /// Character context for screenplay-aware voice casting.
    public var character: Character?

    /// Provenance tracking for voice origin and consent.
    public var provenance: Provenance?

    /// Engine-specific extension data, keyed by provider namespace.
    public var extensions: [String: AnyCodable]?

    /// Structured embedding metadata mapping identifiers to model/file metadata.
    ///
    /// Each key is a human-readable identifier (e.g., `"qwen3-tts-0.6b"`) and the value
    /// describes which model produced the embedding, where the binary file lives in the
    /// archive, and optional format/description hints.
    public var embeddingEntries: [String: EmbeddingEntry]?

    private enum CodingKeys: String, CodingKey {
        case voxVersion = "vox_version"
        case id
        case created
        case voice
        case prosody
        case referenceAudio = "reference_audio"
        case character
        case provenance
        case extensions
        case embeddingEntries = "embeddings"
    }

    public init(
        voxVersion: String,
        id: String,
        created: Date,
        voice: Voice,
        prosody: Prosody? = nil,
        referenceAudio: [ReferenceAudio]? = nil,
        character: Character? = nil,
        provenance: Provenance? = nil,
        extensions: [String: AnyCodable]? = nil,
        embeddingEntries: [String: EmbeddingEntry]? = nil
    ) {
        self.voxVersion = voxVersion
        self.id = id
        self.created = created
        self.voice = voice
        self.prosody = prosody
        self.referenceAudio = referenceAudio
        self.character = character
        self.provenance = provenance
        self.extensions = extensions
        self.embeddingEntries = embeddingEntries
    }
}

// MARK: - Voice

extension VoxManifest {
    /// Core voice identity metadata within a VOX manifest.
    ///
    /// `Voice` contains the required display name and natural language description of the
    /// voice, along with optional attributes like language, gender, age range, and tags.
    /// The `description` field is particularly important as it serves as the primary input
    /// for voice design engines that generate synthetic voices from text descriptions.
    public struct Voice: Codable {
        /// Display name for the voice (e.g., `"Narrator"`, `"PROTAGONIST"`).
        public let name: String

        /// Natural language description of the voice characteristics.
        ///
        /// Must be at least 10 characters. This description is used by voice design engines
        /// to synthesize or match voices. Be specific about accent, tone, age, and personality.
        public let description: String

        /// Primary language of the voice in BCP 47 format (e.g., `"en-US"`, `"en-GB"`, `"fr-FR"`).
        public var language: String?

        /// Gender presentation of the voice.
        ///
        /// Must be one of: `"male"`, `"female"`, `"nonbinary"`, `"neutral"`.
        public var gender: String?

        /// Approximate age range as `[minimum, maximum]` where `minimum < maximum`.
        public var ageRange: [Int]?

        /// Searchable tags describing voice characteristics (e.g., `["narrator", "authoritative"]`).
        public var tags: [String]?

        private enum CodingKeys: String, CodingKey {
            case name
            case description
            case language
            case gender
            case ageRange = "age_range"
            case tags
        }

        public init(
            name: String,
            description: String,
            language: String? = nil,
            gender: String? = nil,
            ageRange: [Int]? = nil,
            tags: [String]? = nil
        ) {
            self.name = name
            self.description = description
            self.language = language
            self.gender = gender
            self.ageRange = ageRange
            self.tags = tags
        }
    }
}

// MARK: - Prosody

extension VoxManifest {
    /// Prosodic preferences describing the voice's natural speaking style.
    ///
    /// `Prosody` captures qualitative descriptions of how the voice should sound in terms
    /// of pitch, speaking rate, energy, and default emotional tone. These are descriptive
    /// strings (not numeric values) to remain engine-agnostic. All fields are optional.
    public struct Prosody: Codable {
        /// Base pitch level (e.g., `"low"`, `"medium"`, `"high"`).
        public var pitchBase: String?

        /// Pitch variation range (e.g., `"narrow"`, `"moderate"`, `"wide"`).
        public var pitchRange: String?

        /// Speaking rate (e.g., `"slow"`, `"moderate"`, `"fast"`).
        public var rate: String?

        /// Overall energy or intensity level (e.g., `"low"`, `"medium"`, `"high"`).
        public var energy: String?

        /// Default emotional tone when no specific emotion is requested (e.g., `"calm authority"`).
        public var emotionDefault: String?

        private enum CodingKeys: String, CodingKey {
            case pitchBase = "pitch_base"
            case pitchRange = "pitch_range"
            case rate
            case energy
            case emotionDefault = "emotion_default"
        }

        public init(
            pitchBase: String? = nil,
            pitchRange: String? = nil,
            rate: String? = nil,
            energy: String? = nil,
            emotionDefault: String? = nil
        ) {
            self.pitchBase = pitchBase
            self.pitchRange = pitchRange
            self.rate = rate
            self.energy = energy
            self.emotionDefault = emotionDefault
        }
    }
}

// MARK: - ReferenceAudio

extension VoxManifest {
    /// Metadata for a reference audio clip used in voice cloning or style matching.
    ///
    /// Each `ReferenceAudio` entry describes one audio file bundled in the `.vox` archive's
    /// `reference/` directory. The `file` path and `transcript` are required; language,
    /// duration, and context are optional. Audio files should be WAV format (24kHz, 16-bit
    /// PCM, mono) for maximum compatibility across TTS engines.
    public struct ReferenceAudio: Codable {
        /// Path to the audio file within the `.vox` archive, relative to the archive root
        /// (e.g., `"reference/sample-01.wav"`).
        public let file: String

        /// Verbatim transcript of the audio clip content.
        public let transcript: String

        /// Language of the audio clip in BCP 47 format (e.g., `"en-US"`).
        public var language: String?

        /// Duration of the audio clip in seconds (e.g., `4.2`).
        public var durationSeconds: Double?

        /// Contextual note about the audio clip (e.g., `"Calm narration, studio recording"`).
        public var context: String?

        private enum CodingKeys: String, CodingKey {
            case file
            case transcript
            case language
            case durationSeconds = "duration_seconds"
            case context
        }

        public init(
            file: String,
            transcript: String,
            language: String? = nil,
            durationSeconds: Double? = nil,
            context: String? = nil
        ) {
            self.file = file
            self.transcript = transcript
            self.language = language
            self.durationSeconds = durationSeconds
            self.context = context
        }
    }
}

// MARK: - Character

extension VoxManifest {
    /// Character context for screenplay-aware voice casting.
    ///
    /// `Character` provides narrative context that helps casting systems select appropriate
    /// voice parameters. It includes the character's role, emotional range, relationships
    /// with other characters, and a reference to the source material. This information
    /// enables context-aware synthesis where the TTS engine can adapt delivery based on
    /// dramatic requirements.
    public struct Character: Codable {
        /// Description of the character's role in the narrative.
        public var role: String?

        /// Range of emotions the character expresses (e.g., `["contemplative", "melancholic", "stern"]`).
        public var emotionalRange: [String]?

        /// Character relationships mapped as character name to relationship description.
        public var relationships: [String: String]?

        /// Source material reference for the character.
        public var source: Source?

        private enum CodingKeys: String, CodingKey {
            case role
            case emotionalRange = "emotional_range"
            case relationships
            case source
        }

        public init(
            role: String? = nil,
            emotionalRange: [String]? = nil,
            relationships: [String: String]? = nil,
            source: Source? = nil
        ) {
            self.role = role
            self.emotionalRange = emotionalRange
            self.relationships = relationships
            self.source = source
        }
    }

    /// Source material reference for a character in the narrative.
    ///
    /// Links a character to the original screenplay, novel, or script that defines it,
    /// enabling traceability from voice identity back to source material.
    public struct Source: Codable {
        /// Title of the source work (e.g., `"The Chronicle"`).
        public var work: String?

        /// Format of the source material (e.g., `"fountain"`, `"screenplay"`, `"novel"`).
        public var format: String?

        /// Path to the source file (e.g., `"episodes/chronicle-episode-01.fountain"`).
        public var file: String?

        public init(
            work: String? = nil,
            format: String? = nil,
            file: String? = nil
        ) {
            self.work = work
            self.format = format
            self.file = file
        }
    }
}

// MARK: - Provenance

extension VoxManifest {
    /// Provenance tracking for voice origin, creation method, and consent status.
    ///
    /// `Provenance` documents how a voice was created and under what terms it may be used.
    /// This is critical for ethical voice cloning: the `method` field distinguishes designed
    /// voices (no real person) from cloned voices (requires consent), and the `consent` field
    /// tracks authorization status. All fields are optional but strongly recommended.
    public struct Provenance: Codable {
        /// How the voice was created: `"designed"`, `"cloned"`, `"preset"`, or `"hybrid"`.
        public var method: String?

        /// TTS engine or tool used to create the voice (e.g., `"qwen3-tts-voicedesign-1.7b"`).
        public var engine: String?

        /// Consent status for voice cloning: `"self"`, `"granted"`, `"unknown"`, or `nil` for designed voices.
        public var consent: String?

        /// License under which the voice is distributed (e.g., `"CC0-1.0"`, `"CC-BY-4.0"`).
        public var license: String?

        /// Additional notes about voice provenance and creation context.
        public var notes: String?

        public init(
            method: String? = nil,
            engine: String? = nil,
            consent: String? = nil,
            license: String? = nil,
            notes: String? = nil
        ) {
            self.method = method
            self.engine = engine
            self.consent = consent
            self.license = license
            self.notes = notes
        }
    }
}

// MARK: - EmbeddingEntry

extension VoxManifest {
    /// Metadata for a single model-specific embedding within a `.vox` archive.
    ///
    /// Each `EmbeddingEntry` describes one binary embedding file and the model that produced it.
    /// This enables a single `.vox` file to carry embeddings for multiple model variants
    /// (e.g., a 0.6B lightweight model and a 1.7B full-quality model).
    public struct EmbeddingEntry: Codable, Sendable, Equatable {
        /// Fully qualified model identifier (e.g., `"Qwen/Qwen3-TTS-12Hz-0.6B"`).
        public let model: String

        /// Engine namespace this embedding belongs to (e.g., `"qwen3-tts"`).
        public var engine: String?

        /// Archive-relative path to the embedding binary (e.g., `"embeddings/qwen3-tts/0.6b/clone-prompt.bin"`).
        public let file: String

        /// Binary format hint (e.g., `"bin"`, `"safetensors"`, `"onnx"`).
        public var format: String?

        /// Human-readable note about this embedding.
        public var description: String?

        public init(
            model: String,
            engine: String? = nil,
            file: String,
            format: String? = nil,
            description: String? = nil
        ) {
            self.model = model
            self.engine = engine
            self.file = file
            self.format = format
            self.description = description
        }
    }
}

// MARK: - AnyCodable Helper

/// Type-erased `Codable` wrapper for heterogeneous JSON values in extension data.
///
/// `AnyCodable` enables the `extensions` dictionary to contain arbitrary JSON structures
/// (strings, numbers, booleans, arrays, and nested objects) from different TTS engine
/// providers. It handles encoding and decoding by inspecting the underlying type at runtime.
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type in AnyCodable"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type in AnyCodable"
                )
            )
        }
    }
}

// MARK: - Date Coding Strategy

extension VoxManifest {
    /// Creates a configured `JSONDecoder` for parsing VOX manifest JSON.
    ///
    /// The decoder uses ISO 8601 date decoding strategy to parse the `created`
    /// timestamp field. Use this decoder for all manifest JSON deserialization.
    ///
    /// - Returns: A `JSONDecoder` configured for VOX manifest parsing.
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Creates a configured `JSONEncoder` for writing VOX manifest JSON.
    ///
    /// The encoder uses ISO 8601 date encoding, pretty-printed output with sorted
    /// keys, producing human-readable JSON with consistent key ordering.
    ///
    /// - Returns: A `JSONEncoder` configured for VOX manifest serialization.
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
