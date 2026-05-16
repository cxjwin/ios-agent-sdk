import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Triggers any named Shortcut from the user's Shortcuts library via the
/// `shortcuts://` URL scheme.
///
/// This bridges the agent into the entire iOS automation ecosystem — anything
/// the user has built as a Shortcut (control HomeKit, query an API, run an
/// AppleScript via the Mac, etc.) becomes callable by the agent.
public struct RunShortcutTool: ToolProtocol {
    public let name = "run_shortcut"
    public let description = "Run a named iOS Shortcut from the user's Shortcuts library. Bridges the agent into the entire iOS automation ecosystem. Input: 'shortcut_name' (required, must match an existing Shortcut name exactly), 'input_text' (optional text to pass)."

    public let isReadOnly = false

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "shortcut_name": [
                    "type": "string",
                    "description": "Exact name of a Shortcut in the user's Shortcuts library.",
                ],
                "input_text": [
                    "type": "string",
                    "description": "Optional text input to pass to the Shortcut.",
                ],
            ],
            "required": ["shortcut_name"],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let name = (input["shortcut_name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else { return "Missing 'shortcut_name' parameter." }
        let inputText = input["input_text"] as? String

        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        var urlString = "shortcuts://run-shortcut?name=\(encodedName)"
        if let inputText, !inputText.isEmpty,
           let encoded = inputText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "&input=text&text=\(encoded)"
        }

        guard let url = URL(string: urlString) else {
            return "Failed to build shortcuts URL."
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
            ? "Launched Shortcut '\(name)'."
            : "Failed to launch Shortcut '\(name)'. Verify it exists in your Shortcuts library."
        #else
        return "UIKit not available. Mock: launched Shortcut '\(name)'."
        #endif
    }
}
