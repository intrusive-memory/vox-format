import Foundation
import ArgumentParser
import VoxFormat
import ZIPFoundation

struct ExtractCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract a .vox archive to a directory.",
        discussion: """
        Unzips a .vox file and extracts all contents (manifest.json, reference audio,
        embeddings) to the specified output directory. Pretty-prints the manifest for
        easy inspection.

        Examples:
          vox extract examples/minimal/narrator.vox --output-dir extracted/
          vox extract examples/character/protagonist.vox --output-dir protagonist-contents/
        """
    )

    @Argument(
        help: "Path to the .vox file to extract",
        completion: .file(extensions: ["vox"])
    )
    var file: String

    @Option(
        name: .long,
        help: "Directory where extracted files will be placed (required)"
    )
    var outputDir: String

    mutating func run() throws {
        let fileURL = URL(fileURLWithPath: file)
        let outputDirURL = URL(fileURLWithPath: outputDir)

        // Create output directory
        do {
            try FileManager.default.createDirectory(
                at: outputDirURL,
                withIntermediateDirectories: true
            )
        } catch {
            print("❌ Failed to create output directory")
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // Extract the ZIP archive
        do {
            guard let archive = Archive(url: fileURL, accessMode: .read) else {
                print("❌ Failed to open .vox file as ZIP archive")
                print("File: \(fileURL.path)")
                throw ExitCode.failure
            }

            print("📦 Extracting: \(fileURL.lastPathComponent)")
            print("Destination: \(outputDirURL.path)")
            print()

            var extractedCount = 0
            for entry in archive {
                let destinationURL = outputDirURL.appendingPathComponent(entry.path)

                // Create parent directory if needed
                let parentDir = destinationURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: parentDir.path) {
                    try FileManager.default.createDirectory(
                        at: parentDir,
                        withIntermediateDirectories: true
                    )
                }

                _ = try archive.extract(entry, to: destinationURL)
                print("  ✓ \(entry.path)")
                extractedCount += 1
            }

            print()
            print("Extracted \(extractedCount) file\(extractedCount == 1 ? "" : "s")")
        } catch {
            print("❌ Extraction failed")
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // Pretty-print the manifest
        let manifestURL = outputDirURL.appendingPathComponent("manifest.json")
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            print()
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Manifest Contents")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()

            do {
                let data = try Data(contentsOf: manifestURL)
                let decoder = VoxManifest.decoder()
                let manifest = try decoder.decode(VoxManifest.self, from: data)

                // Re-encode with pretty printing
                let encoder = VoxManifest.encoder()
                let prettyData = try encoder.encode(manifest)
                if let prettyJSON = String(data: prettyData, encoding: .utf8) {
                    print(prettyJSON)
                }
            } catch {
                // Fallback: just print raw JSON
                if let rawJSON = try? String(contentsOf: manifestURL, encoding: .utf8) {
                    print(rawJSON)
                }
            }

            print()
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }

        print()
        print("✅ Extraction complete")
    }
}
