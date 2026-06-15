import XCTest
import VoxFormat

/// Integration tests that exercise the built `vox` executable as a black box.
///
/// These tests exist to catch a class of failure the library tests cannot: the
/// CLI target (`Sources/vox`) is compiled by the *root* package, while the unit
/// tests build only `implementations/swift`. A CLI referencing a removed or
/// renamed API would pass the library suite yet fail `make release`. Building
/// and launching the binary here keeps the entry point honest and documents its
/// usage surface for any agent reading the test output.
final class VoxCLIIntegrationTests: XCTestCase {

    /// Location of the `vox` binary produced alongside this test bundle.
    private var voxBinary: URL {
        productsDirectory.appendingPathComponent("vox")
    }

    /// The directory containing built products (the test bundle's parent).
    private var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("Could not locate the built-products directory.")
        #else
        return Bundle.main.bundleURL
        #endif
    }

    /// Runs `vox` with the given arguments, returning exit status and combined output.
    @discardableResult
    private func runVox(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = voxBinary
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }

    /// The binary compiles, launches, and `--help` advertises every subcommand.
    func testHelpReportsUsageAndSubcommands() throws {
        let result = try runVox(["--help"])

        XCTAssertEqual(result.status, 0, "vox --help should exit 0.\nOutput:\n\(result.output)")
        XCTAssertTrue(result.output.contains("USAGE"), "Expected a USAGE section.\nOutput:\n\(result.output)")
        XCTAssertTrue(result.output.contains("vox"), "Expected the command name in help.")

        // Every shipped subcommand should be discoverable from --help so agents
        // (and humans) can learn the tool's surface without reading source.
        for subcommand in ["inspect", "validate", "create", "extract"] {
            XCTAssertTrue(
                result.output.contains(subcommand),
                "Expected `--help` to advertise the `\(subcommand)` subcommand.\nOutput:\n\(result.output)"
            )
        }
    }

    /// `--version` reports the format version the library writes.
    func testVersionMatchesFormatVersion() throws {
        let result = try runVox(["--version"])

        XCTAssertEqual(result.status, 0, "vox --version should exit 0.")
        XCTAssertEqual(
            result.output.trimmingCharacters(in: .whitespacesAndNewlines),
            VoxFormat.currentVersion,
            "`vox --version` should match VoxFormat.currentVersion."
        )
    }
}
