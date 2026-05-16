import Foundation

/// Tiny debug-log helper used by the bundled LLM clients. Off by default so
/// nothing prints in release builds; flip `debugLogging: true` on a client to
/// see the request/response trace in Xcode's console.
///
/// Designed so an API key is never printed verbatim — use ``mask(_:)``.
public enum AgentDebug {
    /// Mask an API key for logging. Shows the first 4 and last 4 characters
    /// plus the total length, e.g. `sk-a…wxyz (51 chars)`.
    public static func mask(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return "***(\(trimmed.count) chars)" }
        let prefix = trimmed.prefix(4)
        let suffix = trimmed.suffix(4)
        return "\(prefix)…\(suffix) (\(trimmed.count) chars)"
    }

    /// Truncate long strings (HTTP bodies, JSON dumps) for readable logs.
    public static func truncate(_ s: String, limit: Int = 1024) -> String {
        guard s.count > limit else { return s }
        return String(s.prefix(limit)) + "…(+\(s.count - limit) chars)"
    }

    /// Print a line to stdout if `enabled` is true. Prefixed with `[iOSAgentSDK]`
    /// so Xcode console filtering is one-click.
    public static func log(_ message: @autoclosure () -> String, enabled: Bool) {
        guard enabled else { return }
        print("[iOSAgentSDK] \(message())")
    }
}
