import Foundation
import ArgumentParser
import VoxFormat

struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate a .vox file against the VOX format specification.",
        discussion: """
        Reads a .vox archive and validates its manifest against the VOX format requirements.
        By default, uses permissive validation (forward-compatible). Use --strict for development.

        Examples:
          vox validate examples/minimal/narrator.vox
          vox validate --strict examples/character/protagonist.vox
        """
    )

    @Argument(
        help: "Path to the .vox file to validate",
        completion: .file(extensions: ["vox"])
    )
    var file: String

    @Flag(
        name: .long,
        help: "Use strict validation mode (not forward-compatible)"
    )
    var strict = false

    mutating func run() throws {
        let fileURL = URL(fileURLWithPath: file)

        // Read the .vox file
        let reader = VoxReader()
        let voxFile: VoxFile

        do {
            voxFile = try reader.read(from: fileURL)
        } catch {
            print("❌ FAILED: \(fileURL.lastPathComponent)")
            print()
            print("Error: \(error.localizedDescription)")
            if let voxError = error as? VoxError {
                print("Details: \(voxError)")
            }
            throw ExitCode.failure
        }

        // Validate the manifest
        let validator = VoxValidator()
        do {
            try validator.validate(voxFile.manifest, strict: strict)
        } catch {
            print("❌ VALIDATION FAILED: \(fileURL.lastPathComponent)")
            print()
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // Success
        print("✅ PASS: \(fileURL.lastPathComponent)")
        print()
        print("Validation mode: \(strict ? "strict" : "permissive (default)")")
        print("Voice: \(voxFile.manifest.voice.name)")
        print("Version: \(voxFile.manifest.voxVersion)")

        // Print summary
        var features: [String] = []
        if voxFile.manifest.prosody != nil {
            features.append("prosody")
        }
        if voxFile.manifest.referenceAudio != nil {
            features.append("reference audio")
        }
        if voxFile.manifest.character != nil {
            features.append("character context")
        }
        if voxFile.manifest.provenance != nil {
            features.append("provenance")
        }
        if voxFile.manifest.extensions != nil {
            features.append("extensions")
        }

        if !features.isEmpty {
            print("Features: \(features.joined(separator: ", "))")
        }
    }
}
