import Foundation
import ArgumentParser

struct SearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search the voice library for matching voices.",
        discussion: """
        Searches the library/index.json file for voices matching the query.
        Performs case-insensitive partial matching on name, description, and tags.

        Examples:
          vox-cli search narrator
          vox-cli search young
          vox-cli search --library-path /path/to/library wise
        """
    )

    @Argument(
        help: "Search query (case-insensitive)"
    )
    var query: String

    @Option(
        name: .long,
        help: "Path to library directory (defaults to examples/library)"
    )
    var libraryPath: String?

    mutating func run() throws {
        // Determine library path
        let libPath: String
        if let customPath = libraryPath {
            libPath = customPath
        } else {
            // Default to examples/library relative to current directory
            let currentDir = FileManager.default.currentDirectoryPath
            libPath = (currentDir as NSString).appendingPathComponent("examples/library")
        }

        let indexPath = (libPath as NSString).appendingPathComponent("index.json")
        let indexURL = URL(fileURLWithPath: indexPath)

        guard FileManager.default.fileExists(atPath: indexPath) else {
            FileHandle.standardError.write("Error: Library index not found at \(indexPath)\n".data(using: .utf8)!)
            FileHandle.standardError.write("Hint: Run from repository root or use --library-path\n".data(using: .utf8)!)
            throw ExitCode.failure
        }

        // Read and parse index
        let indexData = try Data(contentsOf: indexURL)
        let voices = try JSONDecoder().decode([LibraryVoiceEntry].self, from: indexData)

        // Search
        let matches = searchVoices(voices, query: query)

        if matches.isEmpty {
            print("No voices found matching '\(query)'")
            return
        }

        print("Found \(matches.count) voice(s) matching '\(query)':\n")
        for voice in matches {
            printVoiceEntry(voice, libraryPath: libPath)
        }
    }

    private func searchVoices(_ voices: [LibraryVoiceEntry], query: String) -> [LibraryVoiceEntry] {
        let queryLower = query.lowercased()
        return voices.filter { voice in
            // Search in name
            if voice.name.lowercased().contains(queryLower) {
                return true
            }
            // Search in description
            if voice.description.lowercased().contains(queryLower) {
                return true
            }
            // Search in tags
            if voice.tags.contains(where: { $0.lowercased().contains(queryLower) }) {
                return true
            }
            return false
        }
    }

    private func printVoiceEntry(_ voice: LibraryVoiceEntry, libraryPath: String) {
        print("  \(voice.name)")
        print("    File: \(libraryPath)/\(voice.file)")
        print("    Description: \(voice.description)")
        print("    Tags: \(voice.tags.joined(separator: ", "))")
        print("    Language: \(voice.language)")
        if let gender = voice.gender {
            print("    Gender: \(gender)")
        }
        if let ageRange = voice.ageRange {
            print("    Age Range: \(ageRange[0])-\(ageRange[1])")
        }
        print()
    }
}

// MARK: - Library Voice Entry Model

struct LibraryVoiceEntry: Codable {
    let file: String
    let name: String
    let description: String
    let tags: [String]
    let language: String
    let gender: String?
    let ageRange: [Int]?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case file
        case name
        case description
        case tags
        case language
        case gender
        case ageRange = "age_range"
        case category
    }
}

