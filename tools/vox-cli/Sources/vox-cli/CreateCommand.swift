import Foundation
import ArgumentParser
import VoxFormat

struct CreateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new .vox file with the specified metadata.",
        discussion: """
        Creates a minimal .vox archive with required fields auto-generated (UUID, timestamp).
        Optionally specify language, gender, and other voice attributes.

        Examples:
          vox-cli create --name "Narrator" --description "A warm, clear narrator voice" --output narrator.vox
          vox-cli create --name "PROTAGONIST" --description "Young adult protagonist, energetic" --language "en-US" --gender "neutral" --output protagonist.vox
          vox-cli create --name "Doc" --description "Documentary narrator, authoritative British accent" --language "en-GB" --output documentary.vox
        """
    )

    @Option(name: .long, help: "Display name for the voice (required)")
    var name: String

    @Option(name: .long, help: "Natural language description of voice characteristics (required, min 10 chars)")
    var description: String

    @Option(name: .shortAndLong, help: "Output file path for the created .vox file (required)")
    var output: String

    @Option(name: .long, help: "Primary language in BCP 47 format (e.g., en-US, en-GB, fr-FR)")
    var language: String?

    @Option(name: .long, help: "Gender presentation: male, female, nonbinary, neutral")
    var gender: String?

    mutating func validate() throws {
        if description.count < 10 {
            throw ValidationError("Description must be at least 10 characters long")
        }
        if let gender = gender {
            let validGenders = ["male", "female", "nonbinary", "neutral"]
            if !validGenders.contains(gender.lowercased()) {
                throw ValidationError("Gender must be one of: \(validGenders.joined(separator: ", "))")
            }
        }
        if !output.hasSuffix(".vox") {
            print("Warning: Output file should have .vox extension. Appending .vox")
            output += ".vox"
        }
    }

    mutating func run() throws {
        let vox = VoxFile(name: name, description: description)

        // Apply optional voice attributes by mutating the manifest.
        if let language = language {
            var voice = vox.manifest.voice
            let updatedVoice = VoxManifest.Voice(
                name: voice.name,
                description: voice.description,
                language: language,
                gender: gender?.lowercased()
            )
            vox.manifest = VoxManifest(
                voxVersion: vox.manifest.voxVersion,
                id: vox.manifest.id,
                created: vox.manifest.created,
                voice: updatedVoice,
                prosody: vox.manifest.prosody,
                referenceAudio: vox.manifest.referenceAudio,
                character: vox.manifest.character,
                provenance: vox.manifest.provenance,
                extensions: vox.manifest.extensions,
                embeddingEntries: vox.manifest.embeddingEntries
            )
        } else if let gender = gender {
            let updatedVoice = VoxManifest.Voice(
                name: vox.manifest.voice.name,
                description: vox.manifest.voice.description,
                gender: gender.lowercased()
            )
            vox.manifest = VoxManifest(
                voxVersion: vox.manifest.voxVersion,
                id: vox.manifest.id,
                created: vox.manifest.created,
                voice: updatedVoice,
                prosody: vox.manifest.prosody,
                referenceAudio: vox.manifest.referenceAudio,
                character: vox.manifest.character,
                provenance: vox.manifest.provenance,
                extensions: vox.manifest.extensions,
                embeddingEntries: vox.manifest.embeddingEntries
            )
        }

        let outputURL = URL(fileURLWithPath: output)

        do {
            try vox.write(to: outputURL)
        } catch {
            print("❌ Failed to create .vox file")
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        print("✅ Created: \(outputURL.lastPathComponent)")
        print()
        print("Voice: \(name)")
        print("ID: \(vox.manifest.id)")
        print("Created: \(ISO8601DateFormatter().string(from: vox.manifest.created))")
        if let lang = language { print("Language: \(lang)") }
        if let gen = gender { print("Gender: \(gen)") }
        print()
        print("Output: \(outputURL.path)")

        print()
        print("Validating created file...")
        let readBack = try VoxFile(contentsOf: outputURL)
        let issues = readBack.validate()
        let errors = issues.filter { $0.severity == .error }
        if errors.isEmpty {
            print("✅ Validation passed")
        } else {
            print("❌ Validation failed:")
            for issue in errors {
                print("  \(issue)")
            }
            throw ExitCode.failure
        }
    }
}
