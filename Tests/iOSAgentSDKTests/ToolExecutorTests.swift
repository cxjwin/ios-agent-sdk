import XCTest
@testable import iOSAgentSDK

/// Tool that sleeps for `delayMs` milliseconds, echoes its `label`, and records
/// the order in which calls finished into a shared recorder. Used to prove
/// `ToolExecutor.execute` actually runs work in parallel AND still returns
/// results in input order.
private struct DelayEchoTool: ToolProtocol {
    let name = "delay_echo"
    let description = "Sleeps for delayMs ms then returns label."
    var inputSchema: [String: Any] {
        ["type": "object", "properties": [:]]
    }

    let recorder: FinishRecorder

    func execute(input: [String: Any]) async throws -> String {
        let label = input["label"] as? String ?? "?"
        let delayMs = input["delayMs"] as? Int ?? 0
        try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
        await recorder.record(label)
        return label
    }
}

private actor FinishRecorder {
    private(set) var order: [String] = []
    func record(_ label: String) { order.append(label) }
}

final class ToolExecutorTests: XCTestCase {
    func testResultsAreReturnedInInputOrderEvenWhenToolsFinishOutOfOrder() async throws {
        let recorder = FinishRecorder()
        let tool = DelayEchoTool(recorder: recorder)

        // Block 0 sleeps longest, block 1 shortest, block 2 in between.
        // So completion order will be 1 → 2 → 0, but results must come back [0, 1, 2].
        let blocks = [
            ToolUseBlock(id: "a", name: "delay_echo", input: ["label": "A", "delayMs": 200]),
            ToolUseBlock(id: "b", name: "delay_echo", input: ["label": "B", "delayMs": 40]),
            ToolUseBlock(id: "c", name: "delay_echo", input: ["label": "C", "delayMs": 100]),
        ]

        let results = await ToolExecutor.execute(blocks: blocks, tools: [tool])

        XCTAssertEqual(results.map { $0.toolUseId }, ["a", "b", "c"], "Results must be ordered by input index.")
        XCTAssertEqual(results.map { $0.content }, ["A", "B", "C"])
        XCTAssertFalse(results.contains { $0.isError })

        let finishOrder = await recorder.order
        XCTAssertEqual(finishOrder, ["B", "C", "A"], "Tools should have actually finished out of order — otherwise the test isn't proving what it claims.")
    }

    func testExecutionIsConcurrentNotSerial() async throws {
        let recorder = FinishRecorder()
        let tool = DelayEchoTool(recorder: recorder)

        // Six tools at 100ms each. Serial → ~600ms. Concurrent → ~100ms plus overhead.
        let blocks = (0..<6).map { i in
            ToolUseBlock(
                id: "t\(i)",
                name: "delay_echo",
                input: ["label": "T\(i)", "delayMs": 100]
            )
        }

        let start = Date()
        let results = await ToolExecutor.execute(blocks: blocks, tools: [tool])
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(results.count, 6)
        // Generous bound so CI noise doesn't flake. Serial would be ~0.6s; we expect ~0.1s.
        XCTAssertLessThan(elapsed, 0.35, "Six 100ms tools took \(elapsed)s — expected concurrent (~0.1s), not serial (~0.6s).")
    }

    func testUnknownToolYieldsErrorResultWithoutBlockingOthers() async throws {
        let recorder = FinishRecorder()
        let tool = DelayEchoTool(recorder: recorder)

        let blocks = [
            ToolUseBlock(id: "ok", name: "delay_echo", input: ["label": "OK", "delayMs": 10]),
            ToolUseBlock(id: "bad", name: "nope", input: [:]),
        ]

        let results = await ToolExecutor.execute(blocks: blocks, tools: [tool])

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].toolUseId, "ok")
        XCTAssertFalse(results[0].isError)
        XCTAssertEqual(results[1].toolUseId, "bad")
        XCTAssertTrue(results[1].isError)
        XCTAssertTrue(results[1].content.contains("Unknown tool"))
    }

    func testEmptyBlocksReturnEmptyResults() async {
        let results = await ToolExecutor.execute(blocks: [], tools: [])
        XCTAssertTrue(results.isEmpty)
    }

    func testOnResultFiresInCompletionOrderNotInputOrder() async throws {
        let recorder = FinishRecorder()
        let tool = DelayEchoTool(recorder: recorder)

        let blocks = [
            ToolUseBlock(id: "a", name: "delay_echo", input: ["label": "A", "delayMs": 200]),
            ToolUseBlock(id: "b", name: "delay_echo", input: ["label": "B", "delayMs": 40]),
            ToolUseBlock(id: "c", name: "delay_echo", input: ["label": "C", "delayMs": 100]),
        ]

        let callbackOrder = CallbackOrder()
        let results = await ToolExecutor.execute(
            blocks: blocks,
            tools: [tool],
            onResult: { index, result in
                callbackOrder.appendSync(index: index, content: result.content)
            }
        )

        // Return value still ordered by input index.
        XCTAssertEqual(results.map { $0.toolUseId }, ["a", "b", "c"])

        // Callbacks fire as each tool actually finishes — B (40ms) → C (100ms) → A (200ms).
        let observed = callbackOrder.snapshot()
        XCTAssertEqual(observed.map { $0.content }, ["B", "C", "A"],
                       "onResult must fire per-completion so the event stream shows real tool latency.")
        XCTAssertEqual(observed.map { $0.index }, [1, 2, 0],
                       "Indices passed to onResult must match the original block position, not finish order.")
    }
}

/// Tiny lock-wrapped recorder for the per-completion callback test. We can't
/// use an `actor` here because `onResult` is a synchronous `@Sendable` closure.
private final class CallbackOrder: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [(index: Int, content: String)] = []

    func appendSync(index: Int, content: String) {
        lock.lock()
        entries.append((index, content))
        lock.unlock()
    }

    func snapshot() -> [(index: Int, content: String)] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }
}
