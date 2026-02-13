import Foundation

/// VOX voice identity manifest structure.
///
/// Represents the metadata and configuration for a voice identity stored in a .vox file.
/// The manifest defines voice characteristics, prosodic preferences, reference audio,
/// character context, and provenance tracking.
public struct VoxManifest: Codable {
    /// Semantic version of the VOX format specification.
    public let voxVersion: String

    /// Unique identifier for this voice identity (UUID v4).
    public let id: String

    /// ISO 8601 timestamp of when this voice identity was created.
    public let created: Date

    /// Core voice identity metadata.
    public let voice: Voice

    /// Prosodic preferences describing the voice's natural speaking style.
    public var prosody: Prosody?

    /// Reference audio clips used for voice cloning or style matching.
    public var referenceAudio: [ReferenceAudio]?

    /// Character context for screenplay-aware voice casting.
    public var character: Character?

    /// Provenance tracking for voice origin and consent.
    public var provenance: Provenance?

    /// Engine-specific extension data.
    public var extensions: [String: AnyCodable]?

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
        extensions: [String: AnyCodable]? = nil
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
    }
}

// MARK: - Voice

extension VoxManifest {
    /// Core voice identity metadata.
    public struct Voice: Codable {
        /// Display name for the voice.
        public let name: String

        /// Natural language description of the voice characteristics.
        public let description: String

        /// Primary language of the voice in BCP 47 format (e.g., en-US, en-GB, fr-FR).
        public var language: String?

        /// Gender presentation of the voice.
        public var gender: String?

        /// Approximate age range as [minimum, maximum].
        public var ageRange: [Int]?

        /// Searchable tags describing voice characteristics.
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
    public struct Prosody: Codable {
        /// Base pitch level (e.g., low, medium, high).
        public var pitchBase: String?

        /// Pitch variation range (e.g., narrow, moderate, wide).
        public var pitchRange: String?

        /// Speaking rate (e.g., slow, moderate, fast).
        public var rate: String?

        /// Overall energy or intensity level (e.g., low, medium, high).
        public var energy: String?

        /// Default emotional tone when no specific emotion is requested.
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
    /// Reference audio clip metadata for voice cloning or style matching.
    public struct ReferenceAudio: Codable {
        /// Path to the audio file within the .vox archive (relative to archive root).
        public let file: String

        /// Verbatim transcript of the audio clip.
        public let transcript: String

        /// Language of the audio clip in BCP 47 format.
        public var language: String?

        /// Duration of the audio clip in seconds.
        public var durationSeconds: Double?

        /// Contextual note about the audio clip.
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
    public struct Character: Codable {
        /// Description of the character's role in the narrative.
        public var role: String?

        /// Range of emotions the character expresses.
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

    /// Source material reference for a character.
    public struct Source: Codable {
        /// Title of the source work.
        public var work: String?

        /// Format of the source material (e.g., fountain, screenplay, novel).
        public var format: String?

        /// Path to the source file.
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
    /// Provenance tracking for voice origin and consent.
    public struct Provenance: Codable {
        /// How the voice was created.
        public var method: String?

        /// TTS engine or tool used to create the voice.
        public var engine: String?

        /// Consent status for voice cloning. Null for designed voices (no person involved).
        public var consent: String?

        /// License under which the voice is distributed.
        public var license: String?

        /// Additional notes about voice provenance.
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

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for heterogeneous extension data.
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
    /// Custom ISO8601 date decoder for manifest parsing.
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Custom ISO8601 date encoder for manifest writing.
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
