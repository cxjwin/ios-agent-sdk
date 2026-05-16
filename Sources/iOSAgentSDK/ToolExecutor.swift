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
        tools: [any ToolProtocol],
        onResult: (@Sendable (Int, ToolResult) -> Void)? = nil
    ) async -> [ToolResult] {
        guard !blocks.isEmpty else { return [] }

        return await withTaskGroup(of: (Int, ToolResult).self) { group in
            for (index, block) in blocks.enumerated() {
                let tool = tools.first(where: { $0.name == block.name })
                group.addTask {
                    let result = await runOne(block: block, tool: tool)
                    onResult?(index, result)
                    return (index, result)
                }
            }

            var indexed: [(Int, ToolResult)] = []
            indexed.reserveCapacity(blocks.count)
            for await pair in group {
                indexed.append(pair)
            }
            indexed.sort { $0.0 < $1.0 }
            return indexed.map { $0.1 }
        }
    }

    private static func runOne(
        block: ToolUseBlock,
        tool: (any ToolProtocol)?
    ) async -> ToolResult {
        guard let tool else {
            return ToolResult(
                toolUseId: block.id,
                content: "Unknown tool: \(block.name)",
                isError: true
            )
        }
        do {
            let output = try await tool.execute(input: block.input)
            return ToolResult(toolUseId: block.id, content: output, isError: false)
        } catch {
            return ToolResult(
                toolUseId: block.id,
                content: "Tool error: \(error)",
                isError: true
            )
        }
    }
}
