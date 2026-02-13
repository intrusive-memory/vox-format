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

    @Option(
        name: .long,
        help: "Display name for the voice (required)"
    )
    var name: String

    @Option(
        name: .long,
        help: "Natural language description of voice characteristics (required, min 10 chars)"
    )
    var description: String

    @Option(
        name: .shortAndLong,
        help: "Output file path for the created .vox file (required)"
    )
    var output: String

    @Option(
        name: .long,
        help: "Primary language in BCP 47 format (e.g., en-US, en-GB, fr-FR)"
    )
    var language: String?

    @Option(
        name: .long,
        help: "Gender presentation: male, female, nonbinary, neutral"
    )
    var gender: String?

    mutating func validate() throws {
        // Validate description length
        if description.count < 10 {
            throw ValidationError("Description must be at least 10 characters long")
        }

        // Validate gender if provided
        if let gender = gender {
            let validGenders = ["male", "female", "nonbinary", "neutral"]
            if !validGenders.contains(gender.lowercased()) {
                throw ValidationError("Gender must be one of: \(validGenders.joined(separator: ", "))")
            }
        }

        // Validate output has .vox extension
        if !output.hasSuffix(".vox") {
            print("Warning: Output file should have .vox extension. Appending .vox")
            output += ".vox"
        }
    }

    mutating func run() throws {
        // Generate UUID and timestamp
        let id = UUID().uuidString.lowercased()
        let created = Date()

        // Create voice metadata
        let voice = VoxManifest.Voice(
            name: name,
            description: description,
            language: language,
            gender: gender?.lowercased()
        )

        // Create manifest
        let manifest = VoxManifest(
            voxVersion: "0.1.0",
            id: id,
            created: created,
            voice: voice
        )

        // Create VoxFile (no reference audio for minimal creation)
        let voxFile = VoxFile(
            manifest: manifest,
            referenceAudioURLs: [],
            extensionsDirectory: nil
        )

        // Write the .vox file
        let outputURL = URL(fileURLWithPath: output)
        let writer = VoxWriter()

        do {
            try writer.write(voxFile, to: outputURL)
        } catch {
            print("❌ Failed to create .vox file")
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // Success
        print("✅ Created: \(outputURL.lastPathComponent)")
        print()
        print("Voice: \(name)")
        print("ID: \(id)")
        print("Created: \(ISO8601DateFormatter().string(from: created))")
        if let lang = language {
            print("Language: \(lang)")
        }
        if let gen = gender {
            print("Gender: \(gen)")
        }
        print()
        print("Output: \(outputURL.path)")

        // Validate the created file
        print()
        print("Validating created file...")
        let reader = VoxReader()
        let readBack = try reader.read(from: outputURL)
        let validator = VoxValidator()
        try validator.validate(readBack.manifest, strict: false)
        print("✅ Validation passed")
    }
}
