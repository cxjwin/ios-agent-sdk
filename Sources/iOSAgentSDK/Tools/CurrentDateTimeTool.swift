import Foundation

/// Returns the current date, time, and day of week.
///
/// Trivial but useful — LLMs don't have a sense of "now" beyond their training cutoff.
/// Without this tool, "今天是周几" can be answered wrong.
public struct CurrentDateTimeTool: ToolProtocol {
    public let name = "get_current_datetime"
    public let description = "Returns the current date, time, and day of week in the user's locale. No input required."

    public var inputSchema: [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        return "Now: \(formatter.string(from: now)) (ISO 8601: \(isoFormatter.string(from: now)))"
    }
}
