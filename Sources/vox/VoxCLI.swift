import Foundation
import ArgumentParser
import VoxFormat

@main
struct VoxCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vox",
        abstract: "A command-line tool for working with .vox voice identity files.",
        discussion: """
        VOX is an open, vendor-neutral file format for voice identities used in text-to-speech synthesis.
        This tool provides commands to inspect, validate, create, and extract .vox archives.
        """,
        version: VoxFormat.currentVersion,
        subcommands: [
            InspectCommand.self,
            ValidateCommand.self,
            CreateCommand.self,
            ExtractCommand.self
        ]
    )
}
