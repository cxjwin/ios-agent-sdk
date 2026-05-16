import Foundation

public protocol LLMClient: Sendable {
    func sendMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String?,
        tools: [[String: Any]]?
    ) async throws -> [String: Any]
}
