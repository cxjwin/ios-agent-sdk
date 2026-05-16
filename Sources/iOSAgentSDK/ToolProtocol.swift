import Foundation

public protocol ToolProtocol: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: [String: Any] { get }
    var isReadOnly: Bool { get }

    func execute(input: [String: Any]) async throws -> String
}

public extension ToolProtocol {
    var isReadOnly: Bool { true }

    func toAPIFormat() -> [String: Any] {
        [
            "name": name,
            "description": description,
            "input_schema": inputSchema,
        ]
    }
}
