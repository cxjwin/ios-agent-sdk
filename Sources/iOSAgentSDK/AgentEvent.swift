import Foundation

/// Events emitted during an agent run for progress tracking.
///
/// Subscribe via ``Agent/runStreaming(_:)`` and consume with `for try await`.
public enum AgentEvent: Sendable {
    /// A new turn (LLM call cycle) has started.
    case turnStarted(turn: Int)

    /// The LLM request is about to be sent.
    case llmRequestStarted(turn: Int)

    /// LLM response received. `hasToolCalls` indicates whether the model
    /// wants to invoke any tools this turn.
    case llmResponseReceived(turn: Int, hasToolCalls: Bool)

    /// About to invoke a tool. `inputJSON` is the tool input as a compact JSON string.
    case toolCallStarted(toolUseId: String, name: String, inputJSON: String)

    /// A tool has finished executing.
    case toolCallFinished(toolUseId: String, name: String, result: String, isError: Bool)

    /// The agent reached its final answer (terminal event).
    case finalAnswer(String)
}
