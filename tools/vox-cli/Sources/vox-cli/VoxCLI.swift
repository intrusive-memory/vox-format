import Foundation
import ArgumentParser

@main
struct VoxCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vox-cli",
        abstract: "A command-line tool for working with .vox voice identity files.",
        discussion: """
        VOX is an open, vendor-neutral file format for voice identities used in text-to-speech synthesis.
        This tool provides commands to inspect, validate, create, and extract .vox archives.
        """,
        version: "0.1.0",
        subcommands: [
            InspectCommand.self,
            ValidateCommand.self,
            CreateCommand.self,
            ExtractCommand.self
        ]
    )
}
