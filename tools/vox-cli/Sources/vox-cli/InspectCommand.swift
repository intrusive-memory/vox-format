import Foundation
import ArgumentParser
import VoxFormat

struct InspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Display detailed information about a .vox file.",
        discussion: """
        Reads a .vox archive and displays its manifest contents, including voice metadata,
        reference audio files, character context, provenance, and extension namespaces.

        Examples:
          vox-cli inspect examples/minimal/narrator.vox
          vox-cli inspect examples/character/protagonist.vox
        """
    )

    @Argument(
        help: "Path to the .vox file to inspect",
        completion: .file(extensions: ["vox"])
    )
    var file: String

    mutating func run() throws {
        let fileURL = URL(fileURLWithPath: file)

        // Read the .vox file
        let reader = VoxReader()
        let voxFile = try reader.read(from: fileURL)
        let manifest = voxFile.manifest

        // Print header
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("VOX File: \(fileURL.lastPathComponent)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        // Core fields
        print("📋 Core Metadata")
        print("  VOX Version: \(manifest.voxVersion)")
        print("  ID: \(manifest.id)")
        print("  Created: \(formatDate(manifest.created))")
        print()

        // Voice
        print("🎤 Voice Identity")
        print("  Name: \(manifest.voice.name)")
        print("  Description: \(manifest.voice.description)")
        if let language = manifest.voice.language {
            print("  Language: \(language)")
        }
        if let gender = manifest.voice.gender {
            print("  Gender: \(gender)")
        }
        if let ageRange = manifest.voice.ageRange {
            print("  Age Range: \(ageRange[0])-\(ageRange[1])")
        }
        if let tags = manifest.voice.tags, !tags.isEmpty {
            print("  Tags: \(tags.joined(separator: ", "))")
        }
        print()

        // Prosody
        if let prosody = manifest.prosody {
            print("🎵 Prosody")
            if let pitchBase = prosody.pitchBase {
                print("  Pitch Base: \(pitchBase)")
            }
            if let pitchRange = prosody.pitchRange {
                print("  Pitch Range: \(pitchRange)")
            }
            if let rate = prosody.rate {
                print("  Rate: \(rate)")
            }
            if let energy = prosody.energy {
                print("  Energy: \(energy)")
            }
            if let emotion = prosody.emotionDefault {
                print("  Default Emotion: \(emotion)")
            }
            print()
        }

        // Reference Audio
        if let refAudio = manifest.referenceAudio, !refAudio.isEmpty {
            print("🎧 Reference Audio (\(refAudio.count) file\(refAudio.count == 1 ? "" : "s"))")
            for (index, audio) in refAudio.enumerated() {
                print("  [\(index + 1)] \(audio.file)")
                print("      Transcript: \"\(audio.transcript.prefix(60))\(audio.transcript.count > 60 ? "..." : "")\"")
                if let language = audio.language {
                    print("      Language: \(language)")
                }
                if let duration = audio.durationSeconds {
                    print("      Duration: \(String(format: "%.1f", duration))s")
                }
            }
            print()

            // List actual files found
            if !voxFile.referenceAudioURLs.isEmpty {
                print("  Found audio files:")
                for url in voxFile.referenceAudioURLs {
                    print("    ✓ \(url.lastPathComponent)")
                }
                print()
            }
        }

        // Character
        if let character = manifest.character {
            print("🎭 Character Context")
            if let role = character.role {
                print("  Role: \(role)")
            }
            if let emotions = character.emotionalRange, !emotions.isEmpty {
                print("  Emotional Range: \(emotions.joined(separator: ", "))")
            }
            if let relationships = character.relationships, !relationships.isEmpty {
                print("  Relationships:")
                for (name, relationship) in relationships {
                    print("    • \(name): \(relationship)")
                }
            }
            if let source = character.source {
                print("  Source:")
                if let work = source.work {
                    print("    Work: \(work)")
                }
                if let format = source.format {
                    print("    Format: \(format)")
                }
                if let file = source.file {
                    print("    File: \(file)")
                }
            }
            print()
        }

        // Provenance
        if let provenance = manifest.provenance {
            print("📜 Provenance")
            if let method = provenance.method {
                print("  Method: \(method)")
            }
            if let engine = provenance.engine {
                print("  Engine: \(engine)")
            }
            if let consent = provenance.consent {
                print("  Consent: \(consent)")
            }
            if let license = provenance.license {
                print("  License: \(license)")
            }
            if let notes = provenance.notes {
                print("  Notes: \(notes)")
            }
            print()
        }

        // Extensions
        if let extensions = manifest.extensions, !extensions.isEmpty {
            print("🔌 Extensions (\(extensions.count) namespace\(extensions.count == 1 ? "" : "s"))")
            for (namespace, _) in extensions.sorted(by: { $0.key < $1.key }) {
                print("  • \(namespace)")
            }
            print()

            // Check for embeddings directory
            if let embeddingsDir = voxFile.extensionsDirectory {
                print("  Embeddings directory: \(embeddingsDir.lastPathComponent)")
                print()
            }
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
