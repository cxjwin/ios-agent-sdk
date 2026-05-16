import Foundation
import iOSAgentSDK

final class MockLLMClient: LLMClient, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [[String: Any]]
    private(set) var callCount = 0
    private(set) var lastTools: [[String: Any]]?

    init(responses: [[String: Any]]) {
        self.responses = responses
    }

    func sendMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String?,
        tools: [[String: Any]]?
    ) async throws -> [String: Any] {
        takeNext(tools: tools)
    }

    private func takeNext(tools: [[String: Any]]?) -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        callCount += 1
        lastTools = tools
        guard !responses.isEmpty else {
            return ["content": [["type": "text", "text": "(no scripted response left)"]],
                    "stop_reason": "end_turn"]
        }
        return responses.removeFirst()
    }
}

struct EchoTool: ToolProtocol {
    let name = "echo"
    let description = "Echoes a string back."
    var inputSchema: [String: Any] {
        ["type": "object",
         "properties": ["text": ["type": "string"]],
         "required": ["text"]]
    }

    func execute(input: [String: Any]) async throws -> String {
        let text = (input["text"] as? String) ?? "<no text>"
        return "ECHO: \(text)"
    }
}

@main
struct MockSmokeTest {
    static func main() async throws {
        print("=== Test 1: end_turn 立刻返回 ===")
        do {
            let client = MockLLMClient(responses: [
                ["content": [["type": "text", "text": "Hello from mock"]],
                 "stop_reason": "end_turn"]
            ])
            let agent = Agent(client: client, model: "mock-1")
            let result = try await agent.run("hi")
            print("agent 返回: \(result)")
            assert(result == "Hello from mock")
            print("PASS\n")
        }

        print("=== Test 2: tool_use → tool_result → end_turn ===")
        do {
            let client = MockLLMClient(responses: [
                [
                    "content": [
                        ["type": "tool_use",
                         "id": "call_1",
                         "name": "echo",
                         "input": ["text": "ping"]]
                    ],
                    "stop_reason": "tool_use"
                ],
                [
                    "content": [["type": "text", "text": "Got it: ECHO: ping"]],
                    "stop_reason": "end_turn"
                ]
            ])
            let agent = Agent(
                client: client,
                model: "mock-1",
                tools: [EchoTool()]
            )
            let result = try await agent.run("echo ping")
            print("agent 返回: \(result)")
            assert(result.contains("Got it"))
            assert(client.callCount == 2)
            print("PASS  (LLM 调用 \(client.callCount) 次)\n")
        }

        print("=== Test 3: maxTurns 触发 ===")
        do {
            let client = MockLLMClient(responses: Array(repeating: [
                "content": [["type": "tool_use",
                             "id": "loop",
                             "name": "echo",
                             "input": ["text": "loop"]]],
                "stop_reason": "tool_use"
            ], count: 20))
            let agent = Agent(
                client: client,
                model: "mock-1",
                tools: [EchoTool()],
                maxTurns: 3
            )
            do {
                _ = try await agent.run("infinite loop test")
                print("FAIL: 应该抛 maxTurnsExceeded")
                exit(1)
            } catch AgentError.maxTurnsExceeded {
                print("PASS  (按预期抛 maxTurnsExceeded,LLM 调用 \(client.callCount) 次)\n")
            }
        }

        print("所有 smoke test 通过。")
    }
}
