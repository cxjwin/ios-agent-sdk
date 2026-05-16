import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Opens the Messages app with a prefilled SMS/iMessage.
///
/// **Demonstrates the Apple sandbox limit**: an iOS agent cannot send messages
/// without user confirmation. This tool prepares the draft; the user taps "Send".
/// This is the same UX constraint that Claude's official iOS app operates under.
public struct ComposeMessageTool: ToolProtocol {
    public let name = "compose_message"
    public let description = "Prepares an SMS/iMessage by opening the Messages app with prefilled content. The user must tap 'Send' to actually send — Apple sandbox prevents agents from sending unattended. Input: 'recipient' (phone number, optional) and 'body' (required)."

    public let isReadOnly = false

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "recipient": [
                    "type": "string",
                    "description": "Recipient phone number, e.g., '13812345678'. Optional — omit to let user pick.",
                ],
                "body": [
                    "type": "string",
                    "description": "Message body to prefill.",
                ],
            ],
            "required": ["body"],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let recipient = (input["recipient"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let body = (input["body"] as? String) ?? ""
        guard !body.isEmpty else { return "Missing 'body' parameter." }

        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        let urlString = recipient.isEmpty
            ? "sms:?body=\(encodedBody)"
            : "sms:\(recipient)?body=\(encodedBody)"

        guard let url = URL(string: urlString) else {
            return "Failed to build SMS URL."
        }

        #if canImport(UIKit) && os(iOS)
        let opened: Bool = await withCheckedContinuation { cont in
            Task { @MainActor in
                UIApplication.shared.open(url, options: [:]) { success in
                    cont.resume(returning: success)
                }
            }
        }
        return opened
            ? "Opened Messages with prefilled draft. User must tap Send."
            : "Failed to open Messages app."
        #else
        return "UIKit not available. Mock: would open Messages to \(recipient) with body '\(body)'."
        #endif
    }
}
