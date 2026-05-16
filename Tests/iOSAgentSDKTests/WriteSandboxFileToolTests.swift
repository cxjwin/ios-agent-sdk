import XCTest
@testable import iOSAgentSDK

final class WriteSandboxFileToolTests: XCTestCase {
    private var tool: WriteSandboxFileTool!
    private var documentsURL: URL!
    private var scratchDir: String!

    override func setUpWithError() throws {
        tool = WriteSandboxFileTool()
        documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        // Per-test sandbox subdir so parallel test runs don't collide.
        scratchDir = "iOSAgentSDKTests/\(UUID().uuidString)"
    }

    override func tearDownWithError() throws {
        let root = documentsURL.appendingPathComponent("iOSAgentSDKTests")
        try? FileManager.default.removeItem(at: root)
    }

    private func path(_ name: String) -> String {
        "\(scratchDir!)/\(name)"
    }

    private func absoluteURL(_ name: String) -> URL {
        documentsURL.appendingPathComponent(path(name))
    }

    func testCreateWritesNewFile() async throws {
        let result = try await tool.execute(input: [
            "path": path("hello.txt"),
            "content": "hi there",
        ])
        XCTAssertTrue(result.hasPrefix("Created "), "got: \(result)")

        let written = try String(contentsOf: absoluteURL("hello.txt"), encoding: .utf8)
        XCTAssertEqual(written, "hi there")
    }

    func testCreateRefusesToOverwriteExistingFile() async throws {
        _ = try await tool.execute(input: [
            "path": path("exists.txt"),
            "content": "original",
        ])
        let second = try await tool.execute(input: [
            "path": path("exists.txt"),
            "content": "replacement",
        ])
        XCTAssertTrue(second.contains("already exists"), "got: \(second)")

        let onDisk = try String(contentsOf: absoluteURL("exists.txt"), encoding: .utf8)
        XCTAssertEqual(onDisk, "original", "create mode must not clobber existing content.")
    }

    func testOverwriteReplacesExistingContent() async throws {
        _ = try await tool.execute(input: [
            "path": path("note.md"),
            "content": "v1",
        ])
        let result = try await tool.execute(input: [
            "path": path("note.md"),
            "content": "v2",
            "mode": "overwrite",
        ])
        XCTAssertTrue(result.contains("Overwrote"), "got: \(result)")

        let onDisk = try String(contentsOf: absoluteURL("note.md"), encoding: .utf8)
        XCTAssertEqual(onDisk, "v2")
    }

    func testAppendExtendsExistingFile() async throws {
        _ = try await tool.execute(input: [
            "path": path("log.txt"),
            "content": "line1\n",
        ])
        let result = try await tool.execute(input: [
            "path": path("log.txt"),
            "content": "line2\n",
            "mode": "append",
        ])
        XCTAssertTrue(result.contains("Appended"), "got: \(result)")

        let onDisk = try String(contentsOf: absoluteURL("log.txt"), encoding: .utf8)
        XCTAssertEqual(onDisk, "line1\nline2\n")
    }

    func testAppendOnMissingFileCreatesIt() async throws {
        let result = try await tool.execute(input: [
            "path": path("fresh.txt"),
            "content": "boot",
            "mode": "append",
        ])
        XCTAssertTrue(result.hasPrefix("Created "), "got: \(result)")
        let onDisk = try String(contentsOf: absoluteURL("fresh.txt"), encoding: .utf8)
        XCTAssertEqual(onDisk, "boot")
    }

    func testIntermediateDirectoriesAreCreated() async throws {
        let result = try await tool.execute(input: [
            "path": path("a/b/c/deep.txt"),
            "content": "x",
        ])
        XCTAssertTrue(result.hasPrefix("Created "), "got: \(result)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: absoluteURL("a/b/c/deep.txt").path))
    }

    func testPathEscapeIsRejected() async throws {
        let result = try await tool.execute(input: [
            "path": "../../etc/passwd",
            "content": "nope",
        ])
        XCTAssertTrue(result.contains("escapes"), "got: \(result)")
    }

    func testMaxBytesIsEnforced() async throws {
        let result = try await tool.execute(input: [
            "path": path("big.txt"),
            "content": String(repeating: "x", count: 100),
            "maxBytes": 10,
        ])
        XCTAssertTrue(result.contains("exceeds maxBytes"), "got: \(result)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: absoluteURL("big.txt").path))
    }

    func testReadAfterWriteRoundTrip() async throws {
        let body = "round-trip body 🌱"
        _ = try await tool.execute(input: [
            "path": path("rt.txt"),
            "content": body,
        ])
        let reader = ReadSandboxFileTool()
        let read = try await reader.execute(input: ["path": path("rt.txt")])
        XCTAssertEqual(read, body)
    }

    func testIsReadOnlyIsFalse() {
        XCTAssertFalse(tool.isReadOnly)
    }
}
