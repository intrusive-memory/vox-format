import Foundation
import ArgumentParser
import VoxFormat

struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate a .vox file against the VOX format specification.",
        discussion: """
        Reads a .vox archive and validates its manifest against the VOX format requirements.

        Examples:
          vox-cli validate examples/minimal/narrator.vox
          vox-cli validate examples/character/protagonist.vox
        """
    )

    @Argument(help: "Path to the .vox file to validate", completion: .file(extensions: ["vox"]))
    var file: String

    mutating func run() throws {
        let fileURL = URL(fileURLWithPath: file)
        let voxFile: VoxFile

        do {
            voxFile = try VoxFile(contentsOf: fileURL)
        } catch {
            print("❌ FAILED: \(fileURL.lastPathComponent)")
            print()
            print("Error: \(error.localizedDescription)")
            if let voxError = error as? VoxError { print("Details: \(voxError)") }
            throw ExitCode.failure
        }

        let issues = voxFile.validate()
        let errors = issues.filter { $0.severity == .error }
        let warnings = issues.filter { $0.severity == .warning }

        if !errors.isEmpty {
            print("❌ VALIDATION FAILED: \(fileURL.lastPathComponent)")
            print()
            for issue in errors {
                print("  \(issue)")
            }
            for issue in warnings {
                print("  \(issue)")
            }
            throw ExitCode.failure
        }

        print("✅ PASS: \(fileURL.lastPathComponent)")
        print()
        print("Voice: \(voxFile.manifest.voice.name)")
        print("Version: \(voxFile.manifest.voxVersion)")

        if !warnings.isEmpty {
            print()
            print("Warnings:")
            for issue in warnings {
                print("  \(issue)")
            }
        }

        var features: [String] = []
        if voxFile.manifest.prosody != nil { features.append("prosody") }
        if voxFile.manifest.referenceAudio != nil { features.append("reference audio") }
        if voxFile.manifest.character != nil { features.append("character context") }
        if voxFile.manifest.provenance != nil { features.append("provenance") }
        if voxFile.manifest.extensions != nil { features.append("extensions") }

        if !features.isEmpty { print("Features: \(features.joined(separator: ", "))") }
    }
}
