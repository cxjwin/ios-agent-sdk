import Foundation

public actor Agent {
    public let model: String
    public let systemPrompt: String?
    public let maxTurns: Int
    public let maxTokens: Int

    let client: any LLMClient
    let tools: [any ToolProtocol]

    private var messages: [[String: Any]] = []

    public init(
        client: any LLMClient,
        model: String = "claude-opus-4-7",
        systemPrompt: String? = nil,
        tools: [any ToolProtocol] = [],
        maxTurns: Int = 10,
        maxTokens: Int = 4096
    ) {
        self.client = client
        self.model = model
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.maxTurns = maxTurns
        self.maxTokens = maxTokens
    }

    /// Streams ``AgentEvent`` values as the agent loop runs.
    /// The stream finishes normally after `.finalAnswer`, or finishes throwing on error.
    public nonisolated func runStreaming(_ userInput: String) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runInternal(userInput) { event in
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Non-streaming convenience: drains ``runStreaming(_:)`` and returns just the final text.
    public func run(_ userInput: String) async throws -> String {
        var finalText = ""
        for try await event in runStreaming(userInput) {
            if case .finalAnswer(let text) = event {
                finalText = text
            }
        }
        return finalText
    }

    public func getMessages() -> [[String: Any]] {
        messages
    }

    public func reset() {
        messages.removeAll()
    }

    // MARK: - Internal loop with event emission

    private func runInternal(
        _ userInput: String,
        emit: @Sendable @escaping (AgentEvent) -> Void
    ) async throws {
        messages.append(["role": "user", "content": userInput])
        let apiTools = tools.isEmpty ? nil : tools.map { $0.toAPIFormat() }

        for turn in 0..<maxTurns {
            try Task.checkCancellation()
            emit(.turnStarted(turn: turn))
            emit(.llmRequestStarted(turn: turn))

            let response = try await client.sendMessage(
                model: model,
                messages: messages,
                maxTokens: maxTokens,
                system: systemPrompt,
                tools: apiTools
            )
            let content = response["content"] as? [[String: Any]] ?? []
            let stopReason = response["stop_reason"] as? String ?? ""

            messages.append(["role": "assistant", "content": content])

            let blocks = ToolExecutor.extractToolUseBlocks(from: content)
            emit(.llmResponseReceived(turn: turn, hasToolCalls: !blocks.isEmpty))

            if stopReason == "end_turn" {
                let text = content
                    .compactMap { $0["text"] as? String }
                    .joined(separator: "\n")
                if !text.isEmpty {
                    emit(.finalAnswer(text))
                }
                return
            }

            guard !blocks.isEmpty else {
                throw AgentError.unexpectedStopReason(stopReason)
            }

            for block in blocks {
                let inputData = (try? JSONSerialization.data(
                    withJSONObject: block.input,
                    options: [.sortedKeys]
                )) ?? Data()
                let inputJSON = String(data: inputData, encoding: .utf8) ?? "{}"
                emit(.toolCallStarted(
                    toolUseId: block.id,
                    name: block.name,
                    inputJSON: inputJSON
                ))
            }

            let results = await ToolExecutor.execute(blocks: blocks, tools: tools)

            for (block, result) in zip(blocks, results) {
                emit(.toolCallFinished(
                    toolUseId: block.id,
                    name: block.name,
                    result: result.content,
                    isError: result.isError
                ))
            }

            messages.append([
                "role": "user",
                "content": results.map { $0.toAPIFormat() },
            ])
        }
        throw AgentError.maxTurnsExceeded
    }
}
