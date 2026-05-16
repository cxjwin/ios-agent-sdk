import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Opens the Mail app with a prefilled draft. User must tap "Send" — same
/// Apple sandbox constraint as `ComposeMessageTool`.
public struct ComposeEmailTool: ToolProtocol {
    public let name = "compose_email"
    public let description = "Prepares an email by opening Mail with prefilled content. The user must tap 'Send' to actually send — Apple sandbox prevents unattended sending. Input: 'to' (recipient email, optional), 'subject' (optional), 'body' (required)."

    public let isReadOnly = false

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "to": ["type": "string", "description": "Recipient email address."],
                "subject": ["type": "string", "description": "Subject line."],
                "body": ["type": "string", "description": "Email body text."],
            ],
            "required": ["body"],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let to = (input["to"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let subject = (input["subject"] as? String) ?? ""
        let body = (input["body"] as? String) ?? ""
        guard !body.isEmpty else { return "Missing 'body' parameter." }

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body

        var query: [String] = []
        if !subject.isEmpty { query.append("subject=\(encodedSubject)") }
        query.append("body=\(encodedBody)")
        let urlString = "mailto:\(to)?\(query.joined(separator: "&"))"

        guard let url = URL(string: urlString) else {
            return "Failed to build mailto URL."
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
            ? "Opened Mail with prefilled draft. User must tap Send."
            : "Failed to open Mail app."
        #else
        return "UIKit not available. Mock: would open Mail to \(to) with subject '\(subject)'."
        #endif
    }
}
