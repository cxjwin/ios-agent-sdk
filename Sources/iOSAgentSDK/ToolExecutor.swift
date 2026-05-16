import Foundation

public struct ToolUseBlock: @unchecked Sendable {
    public let id: String
    public let name: String
    public let input: [String: Any]
}

public struct ToolResult: @unchecked Sendable {
    public let toolUseId: String
    public let content: String
    public let isError: Bool

    public func toAPIFormat() -> [String: Any] {
        [
            "type": "tool_result",
            "tool_use_id": toolUseId,
            "content": content,
            "is_error": isError,
        ]
    }
}

public enum ToolExecutor {
    public static func extractToolUseBlocks(from content: [[String: Any]]) -> [ToolUseBlock] {
        content.compactMap { block in
            guard block["type"] as? String == "tool_use",
                  let id = block["id"] as? String,
                  let name = block["name"] as? String
            else { return nil }
            let input = block["input"] as? [String: Any] ?? [:]
            return ToolUseBlock(id: id, name: name, input: input)
        }
    }

    public static func execute(
        blocks: [ToolUseBlock],
        tools: [any ToolProtocol]
    ) async -> [ToolResult] {
        var results: [ToolResult] = []
        for block in blocks {
            guard let tool = tools.first(where: { $0.name == block.name }) else {
                results.append(ToolResult(
                    toolUseId: block.id,
                    content: "Unknown tool: \(block.name)",
                    isError: true
                ))
                continue
            }
            do {
                let output = try await tool.execute(input: block.input)
                results.append(ToolResult(
                    toolUseId: block.id,
                    content: output,
                    isError: false
                ))
            } catch {
                results.append(ToolResult(
                    toolUseId: block.id,
                    content: "Tool error: \(error)",
                    isError: true
                ))
            }
        }
        return results
    }
}
