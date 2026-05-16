import Foundation

public enum AgentError: Error, CustomStringConvertible {
    case invalidResponse
    case httpError(status: Int, body: String)
    case unexpectedStopReason(String)
    case maxTurnsExceeded
    case missingAPIKey

    public var description: String {
        switch self {
        case .invalidResponse:
            return "Invalid API response"
        case .httpError(let status, let body):
            return "HTTP \(status): \(body)"
        case .unexpectedStopReason(let reason):
            return "Unexpected stop_reason: \(reason)"
        case .maxTurnsExceeded:
            return "Max turns exceeded"
        case .missingAPIKey:
            return "ANTHROPIC_API_KEY not set"
        }
    }
}
