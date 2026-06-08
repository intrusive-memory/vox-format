import XCTest
@testable import VoxFormat

/// Pure-Swift replacement for the former `schemas/validate-examples.sh` gate.
///
/// Validates every shipped example manifest and every negative fixture through the
/// Swift implementation (`VoxManifest` decoding + `VoxFile.validate()`), so example
/// conformance is enforced in `swift test` with no external (Python/Node) validator.
final class SchemaExampleValidationTests: XCTestCase {

    /// Repo-root-relative URL (5 levels up: VoxFormatTests → Tests → swift → implementations → root).
    private func repoURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
    }

    /// Decodes a manifest and returns its `.error`-severity validation issues.
    /// Throws if the JSON cannot even be decoded into a `VoxManifest`.
    private func errors(forManifestAt relativePath: String) throws -> [VoxIssue] {
        let data = try Data(contentsOf: repoURL(relativePath))
        let manifest = try VoxManifest.decoder().decode(VoxManifest.self, from: data)
        return VoxFile(manifest: manifest).validate().filter { $0.severity == .error }
    }

    // MARK: - Positive: every example manifest must validate

    func testAllExampleManifestsValidate() throws {
        let manifests = [
            "examples/minimal/manifest.json",
            "examples/character/narrator-with-context-manifest.json",
            "examples/multi-engine/manifest.json",
            "examples/multi-model/manifest.json",
            "examples/multi-language/manifest.json",
        ]
        for path in manifests {
            let errs = try errors(forManifestAt: path)
            XCTAssertTrue(errs.isEmpty, "\(path) should validate, got: \(errs)")
        }
    }

    func testAllExampleVoxArchivesValidate() throws {
        let archives = [
            "examples/minimal/narrator.vox",
            "examples/character/narrator-with-context.vox",
            "examples/multi-engine/cross-platform.vox",
        ]
        for path in archives {
            let vox = try VoxFile(contentsOf: repoURL(path))
            let errs = vox.validate().filter { $0.severity == .error }
            XCTAssertTrue(errs.isEmpty, "\(path) should validate, got: \(errs)")
        }
    }

    // MARK: - Negative: every invalid fixture must be rejected

    /// A fixture is "rejected" if it fails to decode OR produces an `.error` issue.
    func testNegativeFixturesAreRejected() throws {
        let fixtures = [
            "schemas/test/invalid-age-range.json",        // [55, "old", 30] → decode failure
            "schemas/test/invalid-gender.json",           // "robot" → validate() error
            "schemas/test/invalid-missing-vox-version.json", // missing required → decode failure
            "schemas/test/invalid-timestamp.json",        // bad ISO 8601 → decode failure
            "schemas/test/invalid-uuid.json",             // bad UUID → validate() error
        ]
        for path in fixtures {
            let rejected: Bool
            do {
                rejected = try !errors(forManifestAt: path).isEmpty
            } catch {
                rejected = true // decode threw — correctly rejected
            }
            XCTAssertTrue(rejected, "\(path) should be rejected but passed validation")
        }
    }
}
